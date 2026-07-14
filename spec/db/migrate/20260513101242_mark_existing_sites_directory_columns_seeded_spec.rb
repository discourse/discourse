# frozen_string_literal: true

require Rails.root.join("db/migrate/20260513101242_mark_existing_sites_directory_columns_seeded.rb")

RSpec.describe MarkExistingSitesDirectoryColumnsSeeded do
  before do
    @original_verbose = ActiveRecord::Migration.verbose
    ActiveRecord::Migration.verbose = false
  end

  after do
    ActiveRecord::Migration.verbose = @original_verbose
    Discourse.clear_site_creation_date_cache
  end

  it "is a no-op on fresh installs" do
    DB.exec("UPDATE schema_migration_details SET created_at = NOW()")
    Discourse.clear_site_creation_date_cache

    expect { described_class.new.up }.not_to change {
      DB.query_single(
        "SELECT count(*) FROM site_settings WHERE name = 'directory_columns_seeded'",
      ).first
    }
  end

  context "when the site is an existing install" do
    before do
      DB.exec("UPDATE schema_migration_details SET created_at = NOW() - INTERVAL '2 hours'")
      Discourse.clear_site_creation_date_cache
    end

    it "flips directory_columns_seeded to true so the seed bails on the next deploy" do
      described_class.new.up

      row = DB.query("SELECT value FROM site_settings WHERE name = 'directory_columns_seeded'")[0]
      expect(row.value).to eq("t")
    end
  end
end
