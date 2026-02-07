defmodule Jobs.Repo.Migrations.AddYearsOfExperience do
  use Ecto.Migration

  def change do
    alter table(:listings) do
      add :years_of_experience, :integer
    end
  end
end
