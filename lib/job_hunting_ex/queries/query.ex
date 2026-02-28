defmodule JobHuntingEx.Queries.Query do
  use Ecto.Schema

  schema "query" do
    field :keyword, :string
    field :location, :string
    field :radius, :integer
    field :posted_date, :string
    field :workplace_types, {:array, :string}
    field :minimum_years_of_experience, :integer
    field :maximum_years_of_experience, :integer
  end

  def changeset(query, params \\ %{}) do
    query
    |> Ecto.Changeset.cast(params, [
      :keyword,
      :location,
      :radius,
      :posted_date,
      :workplace_types,
      :minimum_years_of_experience,
      :maximum_years_of_experience
    ])
    |> Ecto.Changeset.validate_required([
      :keyword,
      :minimum_years_of_experience,
      :maximum_years_of_experience
    ])
  end
end
