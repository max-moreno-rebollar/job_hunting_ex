defmodule JobHuntingExWeb.QueryLive.New do
  use JobHuntingExWeb, :live_view
  alias JobHuntingEx.Queries.Query

  def mount(_params, _session, socket) do
    changeset = Query.changeset(%Query{})

    socket =
      socket
      |> assign(form: to_form(changeset))

    {:ok, socket}
  end

  def handle_event("validate", %{"query" => query_params}, socket) do
    changeset =
      Query.changeset(%Query{}, query_params)
      |> Map.put(:action, :validate)

    socket =
      socket
      |> assign(form: to_form(changeset))

    {:noreply, socket}
  end

  def handle_event("search", %{"query" => query_params}, socket) do
    IO.inspect(query_params)
    {:noreply, socket}
  end
end
