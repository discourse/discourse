# frozen_string_literal: true

require Rails.root.join("db/migrate/20260727172505_copy_navigation_menu_site_setting_to_themes.rb")

RSpec.describe CopyNavigationMenuSiteSettingToThemes do
  fab!(:theme_1, :theme)
  fab!(:theme_2, :theme)
  fab!(:component_theme) { Fabricate(:theme, component: true) }

  before do
    @original_verbose = ActiveRecord::Migration.verbose
    ActiveRecord::Migration.verbose = false
    DB.exec("UPDATE schema_migration_details SET created_at = NOW() - INTERVAL '2 hours'")
    Discourse.clear_site_creation_date_cache
  end

  after do
    ActiveRecord::Migration.verbose = @original_verbose
    Discourse.clear_site_creation_date_cache
  end

  def save_navigation_menu(value)
    DB.exec(
      "INSERT INTO site_settings (name, data_type, value, created_at, updated_at)
       VALUES ('navigation_menu', :data_type, :value, NOW(), NOW())
       ON CONFLICT (name)
       DO UPDATE SET data_type = EXCLUDED.data_type, value = EXCLUDED.value, updated_at = NOW()",
      data_type: SiteSettings::TypeSupervisor.types[:enum],
      value:,
    )
  end

  it "copies a saved value to every non-component theme without replacing an existing value" do
    save_navigation_menu("header dropdown")
    existing_theme_value =
      Fabricate(:theme_site_setting, theme: theme_2, name: "navigation_menu", value: "sidebar")

    described_class.new.up

    expect(ThemeSiteSetting.where(name: "navigation_menu").pluck(:theme_id)).to contain_exactly(
      *Theme.where(component: false).pluck(:id),
    )
    expect(ThemeSiteSetting.find_by(theme: theme_1, name: "navigation_menu")).to have_attributes(
      data_type: SiteSettings::TypeSupervisor.types[:enum],
      value: "header dropdown",
    )
    expect(existing_theme_value.reload.value).to eq("sidebar")
    expect(ThemeSiteSetting.find_by(theme: component_theme, name: "navigation_menu")).to eq(nil)

    expect { described_class.new.up }.not_to change {
      ThemeSiteSetting.where(name: "navigation_menu").count
    }
  end

  it "does not create theme records when the global setting has no saved value" do
    described_class.new.up

    expect(ThemeSiteSetting.where(name: "navigation_menu")).to be_empty
  end

  it "is a no-op on fresh installs" do
    DB.exec("UPDATE schema_migration_details SET created_at = NOW()")
    Discourse.clear_site_creation_date_cache
    save_navigation_menu("header dropdown")

    described_class.new.up

    expect(ThemeSiteSetting.where(name: "navigation_menu")).to be_empty
  end
end
