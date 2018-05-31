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

  def new_settings(provider)
    Class.new do
      extend SiteSettingExtension
      self.listen_for_changes = false
      self.provider = provider
    end
  end

  let(:settings) do
    new_settings(provider_local)
  end

  describe 'inserts default_locale into refresh' do
    it 'when initialize' do
      expect(settings.refresh_settings.include?(SiteSettings::DefaultsProvider::DEFAULT_LOCALE_KEY)).to be_truthy
    end
  end

  describe '.db_all' do
    it 'collects values from db except default locale' do
      settings.provider.save(SiteSettings::DefaultsProvider::DEFAULT_LOCALE_KEY,
                             'en',
                             SiteSetting.types[:string])
      expect(settings.defaults.db_all).to eq([])
    end

    it 'can collect values from db' do
      settings.provider.save('try_a', 1, SiteSetting.types[:integer])
      settings.provider.save('try_b', 2, SiteSetting.types[:integer])
      expect(settings.defaults.db_all.count).to eq 2
    end
  end

  describe 'expose default cache according to locale' do
    before do
      settings.setting(:test_override, 'default', locale_default: { zh_CN: 'cn' })
      settings.setting(:test_default, 'test', regex: '^\S+$')
      settings.refresh!
    end

    describe '.all' do
      it 'returns all values according to the current locale' do
        expect(settings.defaults.all).to eq(test_override: 'default', test_default: 'test')
        settings.defaults.site_locale = 'zh_CN'
        settings.defaults.refresh_site_locale!
        expect(settings.defaults.all).to eq(test_override: 'cn', test_default: 'test')
      end
    end

    describe '.get' do
      it 'returns the default value to a site setting' do
        expect(settings.defaults.get(:test_override)).to eq 'default'
      end

      it 'accepts a string as the parameters' do
        expect(settings.defaults.get('test_override')).to eq 'default'
      end

      it 'returns the default value according to current locale' do
        expect(settings.defaults.get(:test_override)).to eq 'default'
        settings.defaults.site_locale = 'zh_CN'
        expect(settings.defaults.get(:test_override)).to eq 'cn'
      end
    end

    describe '.set_regardless_of_locale' do
      let(:val) { 'env_overriden' }

      it 'sets the default value to a site setting regardless the locale' do
        settings.defaults.set_regardless_of_locale(:test_override, val)
        expect(settings.defaults.get(:test_override)).to eq val
        settings.defaults.site_locale = 'zh_CN'
        expect(settings.defaults.get(:test_override)).to eq val
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

    describe '.each' do
      it 'yields the pair of site settings' do
        expect { |b| settings.defaults.each(&b) }.to yield_successive_args([:test_override, 'default'], [:test_default, 'test'])
        settings.defaults.site_locale = 'zh_CN'
        expect { |b| settings.defaults.each(&b) }.to yield_successive_args([:test_override, 'cn'], [:test_default, 'test'])
      end
    end
  end

  describe '.site_locale' do
    it 'returns the current site locale' do
      expect(settings.defaults.site_locale).to eq 'en'
    end

    context 'when locale is set in the db' do
      let(:db_val) { 'zr' }
      let(:global_val) { 'gr' }

      before do
        settings.provider.save(SiteSettings::DefaultsProvider::DEFAULT_LOCALE_KEY,
                               db_val,
                               SiteSetting.types[:string])
        settings.defaults.refresh_site_locale!
      end

      it 'should load from database' do
        expect(settings.defaults.site_locale).to eq db_val
      end

      it 'prioritizes GlobalSetting than value from db' do
        GlobalSetting.stubs(:default_locale).returns(global_val)
        settings.defaults.refresh_site_locale!
        expect(settings.defaults.site_locale).to eq global_val
      end

      it 'ignores blank GlobalSetting' do
        GlobalSetting.stubs(:default_locale).returns('')
        settings.defaults.refresh_site_locale!
        expect(settings.defaults.site_locale).to eq db_val
      end
    end

  end

  describe '.site_locale=' do
    it 'should store site locale in a distributed cache' do
      expect(settings.defaults.class.class_variable_get(:@@site_locales))
        .to be_a(DistributedCache)
    end

    it 'changes and store the current site locale' do
      settings.defaults.site_locale = 'zh_CN'

      expect(settings.defaults.site_locale).to eq('zh_CN')
    end

    it 'changes and store the current site locale' do
      expect { settings.defaults.site_locale = 'random' }.to raise_error(Discourse::InvalidParameters)
      expect(settings.defaults.site_locale).to eq 'en'
    end

    it "don't change when it's shadowed" do
      GlobalSetting.stubs(:default_locale).returns('shadowed')
      settings.defaults.site_locale = 'zh_CN'
      expect(settings.defaults.site_locale).to eq 'shadowed'
    end

    it 'refresh_site_locale! when called' do
      settings.defaults.expects(:refresh_site_locale!)
      settings.defaults.site_locale = 'zh_CN'
    end

    it 'refreshes the client when changed' do
      Discourse.expects(:request_refresh!).once
      settings.defaults.site_locale = 'zh_CN'
    end

    it "doesn't refresh the client when changed" do
      Discourse.expects(:request_refresh!).never
      settings.defaults.site_locale = 'en'
    end
  end

  describe '.locale_setting_hash' do
    it 'returns the hash for client display' do
      result = settings.defaults.locale_setting_hash

      expect(result[:setting]).to eq(SiteSettings::DefaultsProvider::DEFAULT_LOCALE_KEY)
      expect(result[:default]).to eq(SiteSettings::DefaultsProvider::DEFAULT_LOCALE)
      expect(result[:type]).to eq(SiteSetting.types[SiteSetting.types[:enum]])
      expect(result[:preview]).to be_nil
      expect(result[:value]).to eq(SiteSettings::DefaultsProvider::DEFAULT_LOCALE)
      expect(result[:category]).to eq(SiteSettings::DefaultsProvider::DEFAULT_CATEGORY)
      expect(result[:valid_values]).to eq(LocaleSiteSetting.values)
      expect(result[:translate_names]).to eq(LocaleSiteSetting.translate_names?)
      expect(result[:description]).not_to be_nil
    end
  end

  describe '.load_setting' do
    it 'adds a setting to the cache' do
      settings.defaults.load_setting('new_a', 1)
      expect(settings.defaults[:new_a]).to eq 1
    end

    it 'takes care of locale default' do
      settings.defaults.load_setting(:new_b, 1, locale_default: { zh_CN: 2, zh_TW: 2 })
      expect(settings.defaults[:new_b]).to eq 1
    end
  end

  describe '.refresh_site_locale!' do
    it 'loads the change to locale' do
      expect(settings.defaults.site_locale).to eq 'en'
      settings.provider.save(SiteSettings::DefaultsProvider::DEFAULT_LOCALE_KEY,
                             'zh_CN',
                             SiteSetting.types[:string])
      settings.defaults.refresh_site_locale!
      expect(settings.defaults.site_locale).to eq 'zh_CN'
    end

    it 'loads from GlobalSettings' do
      expect(settings.defaults.site_locale).to eq 'en'
      GlobalSetting.stubs(:default_locale).returns('fr')
      settings.defaults.refresh_site_locale!
      expect(settings.defaults.site_locale).to eq 'fr'
    end

    it 'prioritized GlobalSettings than db' do
      expect(settings.defaults.site_locale).to eq 'en'
      settings.provider.save(SiteSettings::DefaultsProvider::DEFAULT_LOCALE_KEY,
                             'zh_CN',
                             SiteSetting.types[:string])
      GlobalSetting.stubs(:default_locale).returns('fr')
      settings.defaults.refresh_site_locale!
      expect(settings.defaults.site_locale).to eq 'fr'
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
      expect(settings.defaults.has_setting?(SiteSettings::DefaultsProvider::DEFAULT_LOCALE_KEY)).to be_truthy
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
