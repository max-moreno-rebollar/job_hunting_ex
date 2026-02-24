defmodule JobHuntingEx.Repo.Migrations.AddSkillsAndSummaryToListings do
  use Ecto.Migration

  def change do
    alter table(:listings) do
      add :skills, {:array, :string}
      add :summary, :text
    end
  end
end
