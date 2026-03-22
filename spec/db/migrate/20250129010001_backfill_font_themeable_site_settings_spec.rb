# frozen_string_literal: true

require Rails.root.join("db/migrate/20250129010001_backfill_font_themeable_site_settings.rb")

RSpec.describe BackfillFontThemeableSiteSettings do
  fab!(:theme_1, :theme)
  fab!(:theme_2, :theme)
  fab!(:theme_3) { Fabricate(:theme, component: true) }

  before do
    @original_verbose = ActiveRecord::Migration.verbose
    ActiveRecord::Migration.verbose = false
  end

  after { ActiveRecord::Migration.verbose = @original_verbose }

  it "backfills base_font and heading_font settings for non-component themes" do
    DB.exec(
      "INSERT INTO site_settings (name, data_type, value, created_at, updated_at)
      VALUES ('base_font', :data_type, :value, NOW(), NOW())",
      data_type: SiteSettings::TypeSupervisor.types[:list],
      value: "roboto",
    )

    BackfillFontThemeableSiteSettings.new.up

    expect(ThemeSiteSetting.where(name: "base_font").count).to eq(4)

    expect(ThemeSiteSetting.where(name: "heading_font").count).to eq(0)

    expect(ThemeSiteSetting.find_by(name: "base_font", theme_id: theme_1.id)).to have_attributes(
      data_type: SiteSettings::TypeSupervisor.types[:list],
      value: "roboto",
    )
  end
end
