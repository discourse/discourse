require 'spec_helper'

describe "i18n integrity checks" do

  it 'should have an i18n key for all trust levels' do
    TrustLevel.all.each do |ts|
      expect(ts.name).not_to match(/translation missing/)
    end
  end

  it "needs an i18n key (description) for each Site Setting" do
    SiteSetting.all_settings.each do |s|
      next if s[:setting] =~ /^test/
      expect(s[:description]).not_to match(/translation missing/)
    end
  end

  it "needs an i18n key (notification_types) for each Notification type" do
    Notification.types.each_key do |type|
      next if type == :custom
      expect(I18n.t("notification_types.#{type}")).not_to match(/translation missing/)
    end
  end

  it "has valid YAML for client" do
    Dir["#{Rails.root}/config/locales/client.*.yml"].each do |f|
      locale = /.*\.([^.]{2,})\.yml$/.match(f)[1]
      client = YAML.load_file("#{Rails.root}/config/locales/client.#{locale}.yml")
      expect(client.count).to eq(1)
      expect(client[locale]).not_to eq(nil)
      expect(client[locale].count).to eq(2)
      expect(client[locale]["js"]).not_to eq(nil)
      expect(client[locale]["admin_js"]).not_to eq(nil)
    end
  end

  it "has valid YAML for server" do
    Dir["#{Rails.root}/config/locales/server.*.yml"].each do |f|
      locale = /.*\.([^.]{2,})\.yml$/.match(f)[1]
      server = YAML.load_file("#{Rails.root}/config/locales/server.#{locale}.yml")
      expect(server.count).to eq(1)
      expect(server[locale]).not_to eq(nil)
    end
  end

  it "does not overwrite another language" do
    Dir["#{Rails.root}/config/locales/*.yml"].each do |f|
      locale = /.*\.([^.]{2,})\.yml$/.match(f)[1] + ':'
      IO.foreach(f) do |line|
        line.strip!
        next if line.start_with? "#"
        next if line.start_with? "---"
        next if line.blank?
        expect(line).to eq locale
        break
      end
    end
  end

end
