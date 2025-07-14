# frozen_string_literal: true

require Rails.root.join("db/migrate/20250714010001_backfill_themeable_site_settings.rb")

RSpec.describe BackfillThemeableSiteSettings do
  fab!(:theme_1) { Fabricate(:theme) }
  fab!(:theme_2) { Fabricate(:theme) }
  fab!(:theme_3) { Fabricate(:theme, component: true) }

  before do
    @original_verbose = ActiveRecord::Migration.verbose
    ActiveRecord::Migration.verbose = false
  end

  after { ActiveRecord::Migration.verbose = @original_verbose }

  it "works" do
    DB.exec(
      "INSERT INTO site_settings (name, data_type, value, created_at, updated_at)
      VALUES ('enable_welcome_banner', :data_type, :value, NOW(), NOW())",
      data_type: SiteSettings::TypeSupervisor.types[:bool],
      value: "t",
    )

    BackfillThemeableSiteSettings.new.up

    # This count includes the system themes and the default theme, but not the component theme.
    expect(ThemeSiteSetting.where(name: "enable_welcome_banner").count).to eq(5)

    # Don't insert any record if the site setting was never changed from the default.
    expect(ThemeSiteSetting.where(name: "search_experience").count).to eq(0)

    # Make sure the data type + value are the same as the site setting.
    expect(
      ThemeSiteSetting.find_by(name: "enable_welcome_banner", theme_id: theme_1.id),
    ).to have_attributes(data_type: SiteSettings::TypeSupervisor.types[:bool], value: "t")
  end
end
