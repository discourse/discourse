# frozen_string_literal: true

require Rails.root.join("db/migrate/20261124183231_keep_mcp_server_disabled_on_existing_sites.rb")

RSpec.describe KeepMcpServerDisabledOnExistingSites do
  before do
    @original_verbose = ActiveRecord::Migration.verbose
    ActiveRecord::Migration.verbose = false
    DB.exec("DELETE FROM site_settings WHERE name = 'mcp_server_enabled'")
  end

  after do
    ActiveRecord::Migration.verbose = @original_verbose
    Discourse.clear_site_creation_date_cache
  end

  def stored_value
    DB.query_single("SELECT value FROM site_settings WHERE name = 'mcp_server_enabled'").first
  end

  it "leaves new sites on the default" do
    DB.exec("UPDATE schema_migration_details SET created_at = NOW()")
    Discourse.clear_site_creation_date_cache

    described_class.new.up

    expect(stored_value).to be_nil
  end

  context "when the site already existed" do
    before do
      DB.exec("UPDATE schema_migration_details SET created_at = NOW() - INTERVAL '2 hours'")
      Discourse.clear_site_creation_date_cache
    end

    it "keeps the MCP server disabled" do
      described_class.new.up

      expect(stored_value).to eq("f")
    end

    it "keeps a server an admin already enabled" do
      DB.exec(<<~SQL)
        INSERT INTO site_settings (name, data_type, value, created_at, updated_at)
        VALUES ('mcp_server_enabled', 5, 't', NOW(), NOW())
      SQL

      described_class.new.up

      expect(stored_value).to eq("t")
    end
  end
end
