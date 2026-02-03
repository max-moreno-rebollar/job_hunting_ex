defmodule JobHuntingEx.Data do
  def polite_sleep do
    :timer.sleep(Enum.random(1..5))
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
  end
end
