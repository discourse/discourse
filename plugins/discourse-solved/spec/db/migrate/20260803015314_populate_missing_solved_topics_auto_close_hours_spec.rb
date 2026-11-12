# frozen_string_literal: true

require Rails.root.join(
          "plugins/discourse-solved/db/migrate/20260803015314_populate_missing_solved_topics_auto_close_hours.rb",
        )

RSpec.describe PopulateMissingSolvedTopicsAutoCloseHours do
  before do
    @original_verbose = ActiveRecord::Migration.verbose
    ActiveRecord::Migration.verbose = false
  end

  after do
    ActiveRecord::Migration.verbose = @original_verbose
    Discourse.clear_site_creation_date_cache
  end

  it "does not create custom fields on fresh installs" do
    category = Fabricate(:category)
    category.upsert_custom_fields("enable_accepted_answers" => "true")
    DB.exec("UPDATE schema_migration_details SET created_at = NOW()")
    Discourse.clear_site_creation_date_cache

    described_class.new.up

    expect(CategoryCustomField.exists?(category:, name: "solved_topics_auto_close_hours")).to eq(
      false,
    )
  end

  context "when the site is an existing install" do
    before do
      DB.exec("UPDATE schema_migration_details SET created_at = NOW() - INTERVAL '2 hours'")
      Discourse.clear_site_creation_date_cache
    end

    it "sets missing fields to zero only for solved categories and preserves existing values" do
      solved_category = Fabricate(:category)
      solved_category.upsert_custom_fields("enable_accepted_answers" => "true")
      configured_category = Fabricate(:category)
      configured_category.upsert_custom_fields(
        "enable_accepted_answers" => "true",
        "solved_topics_auto_close_hours" => "72",
      )
      null_category = Fabricate(:category)
      null_category.upsert_custom_fields("enable_accepted_answers" => "true")
      CategoryCustomField.create!(
        category: null_category,
        name: "solved_topics_auto_close_hours",
        value: nil,
      )
      regular_category = Fabricate(:category)

      2.times { described_class.new.up }

      expect(
        CategoryCustomField.where(
          category: [solved_category, configured_category, null_category, regular_category],
          name: "solved_topics_auto_close_hours",
        ).pluck(:category_id, :value),
      ).to contain_exactly(
        [solved_category.id, "0"],
        [configured_category.id, "72"],
        [null_category.id, "0"],
      )
    end

    it "sets missing fields to zero for every category when solved is allowed globally" do
      DB.exec(<<~SQL, data_type: SiteSettings::TypeSupervisor.types[:bool])
        INSERT INTO site_settings (name, data_type, value, created_at, updated_at)
        VALUES ('allow_solved_on_all_topics', :data_type, 't', NOW(), NOW())
        ON CONFLICT (name) DO UPDATE SET value = EXCLUDED.value
      SQL
      first_category = Fabricate(:category)
      second_category = Fabricate(:category)
      second_category.upsert_custom_fields("solved_topics_auto_close_hours" => "24")
      null_category = Fabricate(:category)
      CategoryCustomField.create!(
        category: null_category,
        name: "solved_topics_auto_close_hours",
        value: nil,
      )

      described_class.new.up

      expect(
        CategoryCustomField.where(
          category: [first_category, second_category, null_category],
          name: "solved_topics_auto_close_hours",
        ).pluck(:category_id, :value),
      ).to contain_exactly(
        [first_category.id, "0"],
        [second_category.id, "24"],
        [null_category.id, "0"],
      )
    end
  end
end
