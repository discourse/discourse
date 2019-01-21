require 'rails_helper'
require_dependency 'site_settings/defaults_provider'

describe SiteSettings::DefaultsProvider do
  let(:provider_local) do
    SiteSettings::LocalProcessProvider.new
  end

  before do
    MessageBus.off
  end

  after do
    MessageBus.on
  end

  let(:settings) do
    new_settings(provider_local)
  end

  describe '.db_all' do
    it 'can collect values from db' do
      settings.provider.save('try_a', 1, SiteSetting.types[:integer])
      settings.provider.save('try_b', 2, SiteSetting.types[:integer])
      expect(settings.defaults.db_all.count).to eq 2
    end
  end

  describe 'expose default cache according to locale' do
    before do
      settings.setting(:test_override, 'default', locale_default: { zh_CN: 'cn' })
      settings.setting(:test_boolean_override, true, locale_default: { zh_CN: false })
      settings.setting(:test_default, 'test', regex: '^\S+$')
      settings.refresh!
    end

    describe '.all' do
      it 'returns all values according to locale' do
        expect(settings.defaults.all).to eq(test_override: 'default', test_default: 'test', test_boolean_override: true)
        expect(settings.defaults.all('zh_CN')).to eq(test_override: 'cn', test_default: 'test', test_boolean_override: false)
      end
    end

    describe '.get' do
      it 'returns the default value to a site setting' do
        expect(settings.defaults.get(:test_override)).to eq 'default'
      end

      it 'accepts a string as the parameters' do
        expect(settings.defaults.get('test_override')).to eq 'default'
      end

      it 'returns the locale_default value if it exists' do
        expect(settings.defaults.get(:test_override, :zh_CN)).to eq 'cn'
        expect(settings.defaults.get(:test_override, :de)).to eq 'default'
        expect(settings.defaults.get(:test_default, :zh_CN)).to eq 'test'
      end

      it 'returns the correct locale_default for boolean site settings' do
        expect(settings.defaults.get(:test_boolean_override, :zh_CN)).to eq false
      end
    end

    describe '.set_regardless_of_locale' do
      let(:val) { 'env_overriden' }

      it 'sets the default value to a site setting regardless the locale' do
        settings.defaults.set_regardless_of_locale(:test_override, val)
        expect(settings.defaults.get(:test_override)).to eq val
        expect(settings.defaults.get(:test_override, 'zh_CN')).to eq val
      end

      it 'handles the string' do
        settings.defaults.set_regardless_of_locale('test_override', val)
        expect(settings.defaults.get(:test_override)).to eq val
      end

      it 'converts the data type' do
        settings.defaults.set_regardless_of_locale(:test_override, 1)
        expect(settings.defaults.get(:test_override)).to eq '1'
      end

      it 'raises when the setting does not exists' do
        expect {
          settings.defaults.set_regardless_of_locale(:not_exist, 1)
        }.to raise_error(ArgumentError)
      end

      it 'raises when the value is not valid' do
        expect {
          settings.defaults.set_regardless_of_locale(:test_default, 'regex will fail')
        }.to raise_error(Discourse::InvalidParameters)
      end
    end
  end

  describe '.load_setting' do
    it 'adds a setting to the cache correctly' do
      settings.defaults.load_setting('new_a', 1, zh_CN: 7)
      expect(settings.defaults[:new_a]).to eq 1
      expect(settings.defaults.get(:new_a, 'zh_CN')).to eq 7
    end
  end

  describe '.has_setting?' do
    before do
      settings.setting(:r, 1)
      settings.setting(:question?, 1)
    end

    it "returns true when it's present in the cache" do
      expect(settings.defaults.has_setting?(:r)).to be_truthy
    end

    it '"responds when the arg is string' do
      expect(settings.defaults.has_setting?('r')).to be_truthy
    end

    it 'default_locale always exists' do
      expect(settings.defaults.has_setting?(:default_locale)).to be_truthy
    end

    it 'returns false when the key is not exist' do
      expect(settings.defaults.has_setting?('no_key')).to be_falsey
    end

    it 'checks name with question mark' do
      expect(settings.defaults.has_setting?(:question)).to be_truthy
      expect(settings.defaults.has_setting?('question')).to be_truthy
    end
  end

end
