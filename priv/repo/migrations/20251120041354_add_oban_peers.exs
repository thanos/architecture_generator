defmodule ArchitectureGenerator.Repo.Migrations.AddObanPeers do
  use Ecto.Migration

  def up do
    Oban.Migration.up(version: 11)
  end

  def down do
    Oban.Migration.down(version: 11)
  end
end
