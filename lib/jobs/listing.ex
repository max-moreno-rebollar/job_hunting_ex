defmodule Jobs.Listing do
  use Ecto.Schema

  schema "listings" do
    field :url, :string
    field :description, :string
    field :embeddings, Pgvector.Ecto.Vector
    field :years_of_experience, :integer
  end

  def changeset(listing, params \\ %{}) do
    listing
    |> Ecto.Changeset.cast(params, [:url, :description, :embeddings, :years_of_experience])
    |> Ecto.Changeset.validate_required([:url, :description, :embeddings])
  end
end
