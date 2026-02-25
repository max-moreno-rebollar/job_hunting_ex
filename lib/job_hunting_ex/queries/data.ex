defmodule JobHuntingEx.Queries.Data do
  require Logger
  alias JobHuntingEx.Jobs.Listings

  defstruct [:url, :html, :description, :classification, :embeddings, :changeset, :error]

  defp polite_sleep do
    :timer.sleep(Enum.random([1_000, 2_000, 3_000]))
  end

  @spec fetch_urls(String.t()) :: list(String.t())
  defp fetch_urls(params) do
    static_params = %{
      "radius_unit" => "mi",
      "jobs_per_page" => 10,
      "posted_date" => "ONE",
      "workplace_types" => ["On-Site", "Hybrid"]
    }

    query_params = Map.merge(params, static_params)

    with {:ok, %{result: payload}} <-
           JobHuntingEx.McpClient.call_tool("search_jobs", query_params),
         %{"content" => [%{"text" => text} | _]} <- payload,
         {:ok, %{"data" => jobs}} <- Jason.decode(text) do
      {:ok, Enum.map(jobs, fn job -> job["detailsPageUrl"] end)}
    else
      {:error, err} -> {:error, IO.inspect(err)}
    end
  end

  @spec extract_description(String.t()) :: {:ok, String.t()} | {:error, String.t()}
  def extract_description(html_string) do
    case Floki.parse_document(html_string) do
      {:ok, document} ->
        description =
          document
          |> Floki.find("[class^='job-detail-description']")
          |> List.first()
          |> Floki.text()

        {:ok, description}

      {:error, err} ->
        {:error, err}
    end
  end

  @spec fetch_html(String.t()) :: {:ok, String.t()} | {:error, String.t()}
  defp fetch_html(url) do
    with {:ok, response} <- Req.get(url),
         {:ok, description} <- extract_description(response.body) do
      case description do
        "" -> {:error, "Description could not be found"}
        _ -> {:ok, description}
      end
    else
      {:error, reason} -> {:error, reason}
    end
  end

  def get_embeddings(documents) do
    body = %{
      "model" => "baai/bge-m3",
      "input" => Enum.map(documents, fn {_url, html} -> html end)
    }

    response =
      Req.post!(
        url: "https://openrouter.ai/api/v1/embeddings",
        headers: [
          authorization: "Bearer ",
          content_type: "application/json"
        ],
        json: body
      )

    Enum.zip(documents, Enum.map(response.body["data"], & &1["embedding"]))
    |> Enum.map(fn {{url, html}, embedding} ->
      %{
        "url" => url,
        "description" => html,
        "embeddings" => embedding
      }
    end)
  end

  def fetch_job_data(html) do
    body = %{
      "model" => "openai/gpt-oss-20b",
      "messages" => [
        %{
          "role" => "user",
          "content" =>
            "You are given a job listing. Determine what the minimum number of years of experience that would qualify someone for this role. Often you will see jobs requiring either a masters and some number of years of experience or a bachelors with more required years of experience. Take the years of expererience as if the applicant doesn't have a masters. You are allowed to make an educated guess on the years of experience based on the title. If it says senior then you can infer the required years of experience is 5 etc. Return the answer or -1 if not found. As well, determine what are the top 5 most needed skills for this role are and limit them to 1 or two words. If there are less than 5 skills needed that's okay. Also provide a one sentence summary of the description. Pay close attention to what you would actually be working on in the job like particular teams. Here is the listing: #{html}"
        }
      ],
      "response_format" => %{
        "type" => "json_schema",
        "json_schema" => %{
          "name" => "listing",
          "strict" => true,
          "schema" => %{
            "type" => "object",
            "properties" => %{
              "minimum_years_of_experience" => %{
                "type" => "number"
              },
              "skills" => %{
                "type" => "array",
                "items" => %{"type" => "string"}
              },
              "summary" => %{
                "type" => "string"
              }
            },
            "required" => ["minimum_years_of_experience", "skills", "summary"],
            "additionalProperties" => false
          }
        }
      }
    }

    response =
      Req.post(
        url: "https://api.groq.com/openai/v1/chat/completions",
        auth: {:bearer, ""},
        json: body
      )

    case response do
      {:ok, res} ->
        IO.inspect(res.body)

        res.body
        |> Map.get("choices")
        |> List.first()
        |> Map.get("message")
        |> Map.get("content")
        |> Jason.decode!()
        |> case do
          %{
            minimum_years_of_experience: years,
            skills: skills,
            summary: summary
          } ->
            %{
              minimum_years_of_experience: years,
              skills: skills,
              summary: summary
            }

          _other ->
            %{
              minimum_years_of_experience: -1,
              skills: "",
              summary: ""
            }
        end

      _error ->
        %{
          "minimum_years_of_experience" => -1,
          "skills" => [],
          "summary" => ""
        }
    end
  end

  # Changes to working with a struct and constructing a list of listings struct
  def process(params) do
    _myoe = params["minimum_years_of_experience"]

    params_modified =
      Map.filter(params, fn {key, _value} -> key != "minimum_years_of_experience" end)

    result =
      with {:ok, urls} <- fetch_urls(params_modified) do
        urls
        |> Task.async_stream(
          fn url ->
            polite_sleep()
            {url, fetch_html(url)}
          end,
          max_concurrency: 2,
          ordered: false,
          timeout: 10_000,
          on_timeout: :kill_task
        )
        |> Stream.flat_map(fn
          {:ok, {url, {:ok, html}}} ->
            [{url, html}]

          {:ok, {_url, {:error, _}}} ->
            []

          {:exit, _} ->
            []
        end)
        |> Stream.chunk_every(25)
        |> Task.async_stream(
          fn batch ->
            get_embeddings(batch)
          end,
          max_concurrency: 2,
          ordered: false,
          timeout: 60_000
        )
        |> Enum.map(fn {:ok, result} -> result end)
        |> List.flatten()
        |> Enum.map(fn listing ->
          job_data = fetch_job_data(listing["description"])
          IO.inspect(job_data)
          :timer.sleep(500)

          listing
          |> Map.put("years_of_experience", job_data.minimum_years_of_experience)
          |> Map.put("skills", job_data.skills)
          |> Map.put("summary", job_data.summary)
        end)
        |> Enum.map(&Listings.create(&1))
        |> Enum.flat_map(fn
          {:ok, struct} -> [struct]
          # throw away all errors for now
          {:error, _struct} -> []
        end)

        # just going to return everything for now
      else
        {:error, err} ->
          Logger.error("Could not query Dice MCP", "reason: #{err}")
          {:error, "Failled on start"}
      end

    result
  end
end
