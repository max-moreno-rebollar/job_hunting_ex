defmodule JobHuntingEx.Jobs.Listings do
  alias JobHuntingEx.Jobs.Listing

  def create(params) do
    %Listing{}
    |> Listing.changeset(params)
    |> JobHuntingEx.Repo.insert()
  end
end
