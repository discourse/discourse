# frozen_string_literal: true

require Rails.root.join(
  "db/migrate/20221212225921_enable_sidebar_and_chat.rb",
)

# To be removed before merging
RSpec.describe "EnableChat" do
  describe 'when the site is new' do
    it 'should enable chat' do
      EnableSidebarAndChat.new.up

      expect(SiteSetting.chat_enabled).to eq(true)
    end
  end

  describe 'when the site is not new' do
    before do
      DB.exec("INSERT INTO schema_migration_details (version, created_at) VALUES (20000225050318, current_date - INTERVAL '1 day')") # Make db creation old
    end

    it 'should set chat to the old default' do
      EnableSidebarAndChat.new.up

      expect(SiteSetting.where(name: "chat_enabled").pluck_first(:value)).to eq('f')
    end
  end

  describe 'when chat is already disabled' do
    before do
      DB.exec("INSERT INTO schema_migration_details (version, created_at) VALUES (20000225050318, current_date - INTERVAL '1 day')") # Make db creation old
      DB.exec("INSERT INTO site_settings (name, data_type, value, created_at, updated_at) VALUES ('chat_enabled', 5, 'f', now(), now())")
    end

    it 'should not enable chat' do
      EnableSidebarAndChat.new.up

      expect(SiteSetting.where(name: "chat_enabled").pluck_first(:value)).to eq('f')
    end
  end

end
