defmodule JobHuntingEx.Data do
  import JobHuntingEx.Jobs

  def polite_sleep do
    :timer.sleep(Enum.random([1_000, 2_000, 3_000]))
  end

  def get_urls(params) do
    with {:ok, %{result: payload}} <- JobHuntingEx.McpClient.call_tool("search_jobs", params),
         %{"content" => [%{"text" => text} | _]} <- payload,
         {:ok, %{"data" => jobs}} <- Jason.decode(text) do
      IO.puts("extrating urls")
      Enum.map(jobs, fn job -> job["detailsPageUrl"] end)
    end
  end

  def get_html(url) do
    html_string = Req.get!(url).body
    {:ok, html} = Floki.parse_document(html_string)
    IO.puts("Retrieved html for #{url}")
    Floki.find(html, "[class^='job-detail-description']") |> List.first() |> Floki.text()
  end

  def get_embeddings(documents) do
    IO.puts("starting getting embeddings")

    body = %{
      "model" => "baai/bge-m3",
      "input" => Enum.map(documents, fn {_url, html} -> html end)
    }

    response =
      Req.post!(
        url: "https://openrouter.ai/api/v1/embeddings",
        headers: [
          authorization: "Bearer #{Application.get_env(:job_hunting_ex, :openrouter_api_key)}",
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

  def extract_years_of_experience(html) do
    patterns = [
      ~r/(\d+)\+?\s*years?\s+of\s+experience/i,
      ~r/(\d+)\+?\s*years?\s+experience/i,
      ~r/(\d+)\+?\s*years?\s+professional\s+experience/i,
      ~r/(\d+)\+?\s*years?\s+relevant\s+experience/i,
      ~r/minimum\s+of\s+(\d+)\s*years?/i,
      ~r/at\s+least\s+(\d+)\s*years?/i
    ]

    years =
      Enum.flat_map(patterns, fn pattern ->
        Regex.scan(pattern, html)
        |> Enum.map(fn [_, num] -> String.to_integer(num) end)
      end)

    case years do
      [] -> nil
      list -> Enum.min(list)
    end
  end

  def process(params) do
    get_urls(params)
    |> Task.async_stream(
      fn url ->
        polite_sleep()
        html = get_html(url)
        {url, html}
      end,
      max_concurrency: 2,
      ordered: false,
      timeout: 10_000
    )
    |> Stream.map(fn {:ok, pair} -> pair end)
    |> Stream.chunk_every(25)
    |> Task.async_stream(fn batch -> get_embeddings(batch) end,
      max_concurrency: 2,
      ordered: false
    )
    |> Enum.map(fn {:ok, result} -> result end)
    |> List.flatten()
    |> then(fn {url, html, embeddings} ->
      min_yoe = extract_years_of_experience(html)
      {url, html, embeddings, min_yoe}
    end)
    |> Enum.each(&create_listing(&1))
  end
end
