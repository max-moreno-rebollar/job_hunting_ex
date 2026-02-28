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
      <div class="flex flex-col items-center pt-10">
        <div class="text-center mb-10">
          <div class="inline-flex items-center justify-center w-12 h-12 rounded-full bg-gray-900 mb-5">
            <.icon name="hero-magnifying-glass" class="w-6 h-6 text-white" />
          </div>
          <h1 class="text-3xl font-bold text-gray-900 tracking-tight">Find Your Next Role</h1>
          <p class="mt-2 text-gray-500 text-sm">Search thousands of job listings tailored to you</p>
        </div>

        <div class="w-full max-w-lg">
          <.form
            for={@form}
            id="search-form"
            phx-submit="search"
            phx-change="validate"
            class="space-y-5"
          >
            <div class="space-y-4">
              <.input
                field={@form[:keyword]}
                type="text"
                label="Keyword"
                placeholder="e.g. Elixir Developer, Product Manager"
              />
              <div class="grid grid-cols-2 gap-4">
                <.input
                  field={@form[:location]}
                  type="text"
                  label="Location"
                  placeholder="e.g. San Francisco"
                />
                <.input
                  field={@form[:radius]}
                  type="text"
                  label="Radius (mi)"
                  placeholder="e.g. 25"
                />
              </div>
              <div class="grid grid-cols-2 gap-4">
                <.input
                  field={@form[:minimum_years_of_experience]}
                  type="text"
                  label="Min. Experience (years)"
                  placeholder="e.g. 1"
                />
                <.input
                  field={@form[:maximum_years_of_experience]}
                  type="text"
                  label="Max. Experience (years)"
                  placeholder="e.g. 15"
                />
              </div>
              <.input
                field={@form[:remote?]}
                type="checkbox"
                label="Include remote jobs"
              />
            </div>

            <.button
              class="w-full bg-gray-900 hover:bg-gray-800 text-white font-medium py-2.5 px-4 rounded-lg transition-colors duration-150 cursor-pointer"
              phx-disable-with="Searching..."
            >
              Search Jobs
            </.button>
          </.form>
        </div>
      </div>
    </Layouts.app>
    """
  end

  def render(%{view: :show} = assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <.async_result :let={listings} assign={@listings}>
        <:loading>
          <div class="flex flex-col items-center justify-center py-20">
            <div class="w-8 h-8 rounded-full border-2 border-gray-200 border-t-gray-900 animate-spin mb-4" />
            <p class="text-gray-500 text-sm">Searching for listings...</p>
          </div>
        </:loading>
        <:failed :let={_reason}>
          <div class="flex flex-col items-center justify-center py-20 text-center">
            <div class="inline-flex items-center justify-center w-12 h-12 rounded-full bg-red-50 mb-4">
              <.icon name="hero-exclamation-triangle" class="w-6 h-6 text-red-500" />
            </div>
            <p class="text-gray-900 font-semibold">Something went wrong</p>
            <p class="text-gray-500 text-sm mt-1">
              Failed to load listings. Please try again.
            </p>
          </div>
        </:failed>

        <div>
          <div class="flex items-center justify-between mb-6">
            <h2 class="text-lg font-semibold text-gray-900">
              {length(listings)} {if length(listings) == 1, do: "result", else: "results"}
            </h2>
            <.link
              navigate="/new"
              class="inline-flex items-center text-sm font-medium text-gray-600 hover:text-gray-900 transition-colors"
            >
              <.icon name="hero-arrow-left" class="w-4 h-4 mr-1" /> New search
            </.link>
          </div>

          <div class="divide-y divide-gray-100">
            <%= for listing <- listings do %>
              <a
                href={listing.url}
                target="_blank"
                class="block py-4 first:pt-0 last:pb-0 group"
              >
                <div class="flex items-start justify-between gap-3 mb-2">
                  <p class="text-sm font-medium text-gray-900 group-hover:text-gray-600 transition-colors truncate">
                    {listing.url}
                  </p>
                  <.icon
                    name="hero-arrow-top-right-on-square"
                    class="w-4 h-4 text-gray-300 group-hover:text-gray-500 shrink-0 transition-colors"
                  />
                </div>

                <p class="text-sm text-gray-500 leading-relaxed line-clamp-2 mb-3">
                  {listing.summary}
                </p>

                <div class="flex flex-wrap items-center gap-1.5">
                  <span class="inline-flex items-center gap-1 text-xs font-medium text-gray-700 bg-gray-100 px-2 py-0.5 rounded-md">
                    {listing.years_of_experience}+ yrs
                  </span>
                  <span
                    :for={skill <- Enum.take(listing.skills, 5)}
                    class="text-xs text-gray-500 bg-gray-50 border border-gray-200 px-2 py-0.5 rounded-md"
                  >
                    {skill}
                  </span>
                  <span
                    :if={length(listing.skills) > 5}
                    class="text-xs text-gray-400"
                  >
                    +{length(listing.skills) - 5} more
                  </span>
                </div>
              </a>
            <% end %>
          </div>
        </div>
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

  def handle_async(:query, {:ok, {:error, reason}}, socket) do
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
