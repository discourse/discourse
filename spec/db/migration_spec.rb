# frozen_string_literal: true

require Rails.root.join(
  "db/migrate/20221205225450_migrate_sidebar_site_settings",
)

# To be removed before merging
RSpec.describe "MigrateSidebarSiteSettings" do
  describe 'when enable_experimental_sidebar_hamburger is true' do
    before do
      DB.exec("INSERT INTO site_settings (name, data_type, value, created_at, updated_at) VALUES ('enable_experimental_sidebar_hamburger', 5, 't', now(), now())")
    end

    describe 'when enable_sidebar is true' do
      before do
        DB.exec("INSERT INTO site_settings (name, data_type, value, created_at, updated_at) VALUES ('enable_sidebar', 5, 't', now(), now())")
      end

      it 'should set navigation_menu to sidebar' do
        MigrateSidebarSiteSettings.new.up

        expect(SiteSetting.where(name: "navigation_menu").pluck_first(:value)).to eq("sidebar")
      end
    end

    describe 'when enable_sidebar is false' do
      before do
        DB.exec("INSERT INTO site_settings (name, data_type, value, created_at, updated_at) VALUES ('enable_sidebar', 5, 'f', now(), now())")
      end

      it 'should set navigation_menu to header dropdown' do
        MigrateSidebarSiteSettings.new.up

        expect(SiteSetting.where(name: "navigation_menu").pluck_first(:value)).to eq("header dropdown")
      end
    end

    describe 'when enable_sidebar has not been set' do
      it 'should set navigation_menu to header dropdown' do
        MigrateSidebarSiteSettings.new.up

        expect(SiteSetting.where(name: "navigation_menu").pluck_first(:value)).to eq("sidebar")
      end
    end
  end

  describe 'when enable_experimental_sidebar_hamburger has not been set' do
    describe 'when enable_sidebar is true' do
      before do
        DB.exec("INSERT INTO site_settings (name, data_type, value, created_at, updated_at) VALUES ('enable_sidebar', 5, 't', now(), now())")
      end

      it 'should not insert row for navigation menu site setting' do
        MigrateSidebarSiteSettings.new.up

        expect(SiteSetting.exists?(name: "navigation_menu")).to eq(false)
      end
    end

    describe 'when enable_sidebar is false' do
      before do
        DB.exec("INSERT INTO site_settings (name, data_type, value, created_at, updated_at) VALUES ('enable_sidebar', 5, 'f', now(), now())")
      end

      it 'should not insert row for navigation menu site setting' do
        MigrateSidebarSiteSettings.new.up

        expect(SiteSetting.exists?(name: "navigation_menu")).to eq(false)
      end
    end

    describe 'when enable_sidebar has not been set' do
      it 'should not insert row for navigation menu site setting' do
        MigrateSidebarSiteSettings.new.up

        expect(SiteSetting.exists?(name: "navigation_menu")).to eq(false)
      end
    end
  end

  describe 'when enable_experimental_sidebar_hamburger is false' do
    before do
      DB.exec("INSERT INTO site_settings (name, data_type, value, created_at, updated_at) VALUES ('enable_experimental_sidebar_hamburger', 5, 'f', now(), now())")
    end

    describe 'when enable_sidebar has not been set' do
      it 'should set navigation_menu to legacy' do
        MigrateSidebarSiteSettings.new.up

        expect(SiteSetting.where(name: "navigation_menu").pluck_first(:value)).to eq("legacy")
      end
    end

    describe 'when enable_sidebar is true' do
      before do
        DB.exec("INSERT INTO site_settings (name, data_type, value, created_at, updated_at) VALUES ('enable_sidebar', 5, 't', now(), now())")
      end

      it 'should set navigatio menu to legacy' do
        MigrateSidebarSiteSettings.new.up

        expect(SiteSetting.where(name: "navigation_menu").pluck_first(:value)).to eq("legacy")
      end
    end

    describe 'when enable_sidebar is false' do
      before do
        DB.exec("INSERT INTO site_settings (name, data_type, value, created_at, updated_at) VALUES ('enable_sidebar', 5, 'f', now(), now())")
      end

      it 'should set navigation_menu to legacy' do
        MigrateSidebarSiteSettings.new.up

        expect(SiteSetting.where(name: "navigation_menu").pluck_first(:value)).to eq("legacy")
      end
    end
  end
end
