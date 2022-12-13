# frozen_string_literal: true

require Rails.root.join(
  "db/migrate/20221212225921_enable_sidebar_and_chat.rb",
)

# To be removed before merging
RSpec.describe "EnableSidebar" do
  describe 'when the site is new' do
    before do
      DB.exec("DELETE FROM site_settings WHERE name = 'navigation_menu'")
    end

    it 'should set navigation_menu to sidebar' do
      EnableSidebarAndChat.new.up

      expect(SiteSetting.navigation_menu).to eq("sidebar")
    end
  end

  describe 'site is not new' do
    before do
      DB.exec("DELETE FROM site_settings WHERE name = 'navigation_menu'")
      DB.exec("INSERT INTO schema_migration_details (version, created_at) VALUES (20000225050318, current_date - INTERVAL '1 day')") # Make db creation old
    end

    it 'should set navigation_menu to old default' do
      EnableSidebarAndChat.new.up

      expect(SiteSetting.where(name: "navigation_menu").pluck_first(:value)).to eq("legacy")
    end
  end

  describe 'when header dropdown is set' do
    before do
      DB.exec("DELETE FROM site_settings WHERE name = 'navigation_menu'")
      DB.exec("INSERT INTO schema_migration_details (version, created_at) VALUES (20000225050318, current_date - INTERVAL '1 day')") # Make db creation old
      DB.exec("INSERT INTO site_settings (name, data_type, value, created_at, updated_at) VALUES ('navigation_menu', 7, 'header_dropdown', now(), now())")
    end

    it 'should not set navigation_menu to sidebar' do
      EnableSidebarAndChat.new.up

      expect(SiteSetting.where(name: "navigation_menu").pluck_first(:value)).to eq("header_dropdown")
    end
  end

  describe 'when legacy is set' do
    before do
      DB.exec("DELETE FROM site_settings WHERE name = 'navigation_menu'")
      DB.exec("INSERT INTO schema_migration_details (version, created_at) VALUES (20000225050318, current_date - INTERVAL '1 day')") # Make db creation old
      DB.exec("INSERT INTO site_settings (name, data_type, value, created_at, updated_at) VALUES ('navigation_menu', 7, 'legacy', now(), now())")
    end

    it 'should not set navigation_menu to sidebar' do
      EnableSidebarAndChat.new.up

      expect(SiteSetting.where(name: "navigation_menu").pluck_first(:value)).to eq("legacy")
    end
  end

end
