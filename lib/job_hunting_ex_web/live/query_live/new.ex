defmodule JobHuntingExWeb.QueryLive.New do
  use JobHuntingExWeb, :live_view
  alias JobHuntingEx.Queries.Query
  alias JobHuntingEx.Queries.Data
  alias Phoenix.LiveView.AsyncResult

  def mount(_params, _session, socket) do
    changeset = Query.changeset(%Query{})

    socket =
      socket
      |> assign(view: :form)
      |> assign(form: to_form(changeset))

    {:ok, socket}
  end

  def render(%{view: :form} = assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <p>Query</p>
      <.form for={@form} phx-submit="search" phx-change="validate">
        <.input field={@form[:keyword]} type="text" label="keyword" />
        <.input field={@form[:location]} type="text" label="location" />
        <.input field={@form[:radius]} type="text" label="radius" />
        <.input
          field={@form[:minimum_years_of_experience]}
          type="text"
          label="minimum years of experience"
        />
        <.button>Search</.button>
      </.form>
    </Layouts.app>
    """
  end

  def render(%{view: :show} = assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <.async_result :let={listings} assign={@listings}>
        <:loading>Loading listings...</:loading>
        <:failed :let={_reason}>Failed to load</:failed>

        <%= for listing <- listings do %>
          <p>{listing.url}, {listing.years_of_experience}</p>
        <% end %>
      </.async_result>
    </Layouts.app>
    """
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
    socket =
      socket
      |> assign(:view, :show)
      |> assign(:listings, AsyncResult.loading())
      |> start_async(:query, fn -> Data.process(query_params) end)

    {:noreply, socket}
  end

  def handle_async(:query, {:ok, fetched_listings}, socket) do
    %{listings: listings} = socket.assigns

    socket =
      socket
      |> assign(:listings, AsyncResult.ok(listings, fetched_listings))

    {:noreply, socket}
  end

  def hanle_async(:query, {:exit, reason}, socket) do
    %{listings: listings} = socket.assigns

    socket =
      socket
      |> assign(
        :listings,
        AsyncResult.failed(
          listings,
          {:exit, assign(socket, :listings, AsyncResult.failed(listings, {:exit, reason}))}
        )
      )

    {:noreply, socket}
  end

  def handle_info("done", socket) do
    {:noreply, socket |> put_flash(:info, "query succeeded")}
  end

  def handle_info("failed", socket) do
    {:noreply, socket |> put_flash(:info, "query failed")}
  end
end
