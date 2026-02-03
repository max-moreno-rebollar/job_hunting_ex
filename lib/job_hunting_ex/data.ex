defmodule JobHuntingEx.Data do
  def get_urls(params) do
    with {:ok, %{result: payload}} <- JobHuntingEx.McpClient.call_tool("search_jobs", params),
         %{"content" => [%{"text" => text} | _]} <- payload,
         {:ok, %{"data" => jobs}} <- Jason.decode(text) do
      IO.puts("extrating urls")
      Enum.map(jobs, fn job -> job["detailsPageUrl"] end)
    end
  end

  def get_html(url) do
  end

  def get_embeddings(documents) do
  end
end
