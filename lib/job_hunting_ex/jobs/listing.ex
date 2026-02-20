defmodule JobHuntingEx.Jobs.Listing do
  use Ecto.Schema
  import Ecto.Changeset

  schema "job_listings" do
    field :url, :string
    field :description, :string
    field :embeddings, Pgvector.Ecto.Vector
    field :years_experience, :integer

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(listing, attrs) do
    listing
    |> cast(attrs, [:url, :description, :years_experience])
    |> validate_required([:url, :description])
  end
end
