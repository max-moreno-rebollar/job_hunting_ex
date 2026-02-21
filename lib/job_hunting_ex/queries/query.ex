defmodule JobHuntingEx.Queries.Query do
  use Ecto.Schema

  schema "query" do
    field :keyword, :string
    field :location, :string
    field :radius, :integer
    field :posted_date, :string
    field :workplace_types, {:array, :string}
  end

  def changeset(query, params \\ %{}) do
    query
    |> Ecto.Changeset.cast(params, [
      :keyword,
      :location,
      :radius,
      :posted_date,
      :workplace_types
    ])
    |> Ecto.Changeset.validate_required([:keyword])
  end
end
