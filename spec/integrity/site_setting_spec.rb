require "rails_helper"
require "i18n/duplicate_key_finder"

describe "site setting integrity checks" do
  let(:site_setting_file) { File.join(Rails.root, 'config', 'site_settings.yml') }
  let(:yaml) { YAML.load_file(site_setting_file) }

  %w(hidden client).each do |property|
    it "set #{property} value as true or not set" do
      yaml.each_value do |category|
        category.each_value do |setting|
          next unless setting.is_a?(Hash)
          expect(setting[property] == nil || setting[property] == true).to be_truthy
        end
      end
    end
  end

  it "has no duplicate keys" do
    duplicates = DuplicateKeyFinder.new.find_duplicates(site_setting_file)
    expect(duplicates).to be_empty
  end

  it "no locale default has different type than default or invalid key" do
    yaml.each_value do |category|
      category.each_value do |setting|
        next unless setting.is_a?(Hash)
        if setting['locale_default']
          setting['locale_default'].each_pair do |k, v|
            expect(LocaleSiteSetting.valid_value?(k.to_s)).to be_truthy
            case setting['default']
            when TrueClass, FalseClass
              expect(v.class == TrueClass || v.class == FalseClass).to be_truthy
            else
              expect(v).to be_a_kind_of(setting['default'].class)
            end
          end
        end
      end
    end
  end
end
