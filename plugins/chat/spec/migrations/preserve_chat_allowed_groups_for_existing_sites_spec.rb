# frozen_string_literal: true

require Rails.root.join(
          "plugins/chat/db/migrate/20261013183208_preserve_chat_allowed_groups_for_existing_sites.rb",
        )

RSpec.describe PreserveChatAllowedGroupsForExistingSites do
  before do
    Migration::Helpers.stubs(:site_created_at).returns(2.days.ago)
    DB.exec("DELETE FROM site_settings WHERE name = 'chat_allowed_groups'")
  end

  def migrate
    migration = described_class.new
    migration.suppress_messages { migration.up }
  end

  it "preserves the old default on existing sites and can run again" do
    2.times { migrate }

    expect(
      DB.query_single("SELECT value FROM site_settings WHERE name = 'chat_allowed_groups'"),
    ).to eq(["1|2|11"])
    expect(
      DB.query_single("SELECT data_type FROM site_settings WHERE name = 'chat_allowed_groups'"),
    ).to eq([SiteSettings::TypeSupervisor.types[:group_list]])
  end

  it "preserves custom groups on existing sites" do
    DB.exec <<~SQL
      INSERT INTO site_settings(name, data_type, value, created_at, updated_at)
      VALUES('chat_allowed_groups', 20, '1|2|4|10', NOW(), NOW())
    SQL

    migrate

    expect(
      DB.query_single("SELECT value FROM site_settings WHERE name = 'chat_allowed_groups'"),
    ).to eq(["1|2|4|10"])
  end

  it "leaves new sites using the new default without inserting a setting" do
    Migration::Helpers.stubs(:site_created_at).returns(Time.current)

    migrate

    expect(
      DB.query_single("SELECT value FROM site_settings WHERE name = 'chat_allowed_groups'"),
    ).to be_empty
    expect(SiteSetting.defaults[:chat_allowed_groups]).to eq("1|2|4|10")
  end
end
