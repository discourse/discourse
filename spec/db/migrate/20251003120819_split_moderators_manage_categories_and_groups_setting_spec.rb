# frozen_string_literal: true

require Rails.root.join(
          "db/migrate/20251003120819_split_moderators_manage_categories_and_groups_setting.rb",
        )

RSpec.describe SplitModeratorsManageCategoriesAndGroupsSetting do
  fab!(:theme_1) { Fabricate(:theme) }
  fab!(:theme_2) { Fabricate(:theme) }
  fab!(:theme_3) { Fabricate(:theme, component: true) }

  subject(:migrate) { described_class.new.up }

  before do
    @original_verbose = ActiveRecord::Migration.verbose
    ActiveRecord::Migration.verbose = false
    DB.exec(<<~SQL)
      INSERT INTO site_settings
        (name, data_type, value, created_at, updated_at)
        VALUES
        ('some_other_setting', 5, 't', NOW(), NOW())
    SQL
  end

  after { ActiveRecord::Migration.verbose = @original_verbose }

  context "when the moderators_manage_categories_and_groups setting does not exist" do
    it "doesn't do anything" do
      expect do migrate end.not_to change {
        DB.query_single("SELECT COUNT(*) FROM site_settings").first
      }
    end
  end

  context "when the moderators_manage_categories_and_groups setting exists" do
    before { DB.exec(<<~SQL) }
        INSERT INTO site_settings
          (name, data_type, value, created_at, updated_at)
          VALUES
          ('moderators_manage_categories_and_groups', 5, 't', NOW(), NOW())
      SQL

    it "inserts the moderators_manage_groups and moderators_manage_categories settings" do
      expect do migrate end.to change {
        DB.query_single(
          "SELECT value FROM site_settings WHERE name = 'moderators_manage_categories'",
        ).first
      }.from(nil).to("t").and change {
              DB.query_single(
                "SELECT value FROM site_settings WHERE name = 'moderators_manage_groups'",
              ).first
            }.from(nil).to("t")
    end

    it "removes the moderators_manage_categories_and_groups setting" do
      expect do migrate end.to change {
        DB.query_single(
          "SELECT COUNT(*) FROM site_settings WHERE name = 'moderators_manage_categories_and_groups'",
        ).first
      }.from(1).to(0)
    end

    it "doesn't affect other settings" do
      expect do migrate end.not_to change {
        DB.query_single(
          "SELECT COUNT(*) FROM site_settings WHERE name = 'some_other_setting'",
        ).first
      }
    end
  end
end
