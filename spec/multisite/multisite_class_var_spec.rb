require 'rails_helper'
require 'multisite_class_var'

RSpec.describe MultisiteClassVar do

  it "will add the class variables" do
    class_with_set = Class.new do
      include MultisiteClassVar
      multisite_class_var(:class_set) { Set.new }
      multisite_class_var(:class_array) { Array.new }
    end

    class_with_set.class_set << 'a'
    class_with_set.class_array << 'c'

    expect(class_with_set.class_set).to contain_exactly('a')
    expect(class_with_set.class_array).to contain_exactly('c')
  end

  context "multisite environment" do
    let(:conn) { RailsMultisite::ConnectionManagement }

    before do
      @original_provider = SiteSetting.provider
      SiteSetting.provider = SiteSettings::DbProvider.new(SiteSetting)
      conn.config_filename = "spec/fixtures/multisite/two_dbs.yml"
      conn.load_settings!
      conn.remove_class_variable(:@@current_db)
    end

    after do
      [:@@db_spec_cache, :@@host_spec_cache, :@@default_spec].each do |class_variable|
        conn.remove_class_variable(class_variable)
      end
      conn.set_current_db
    end

    it "keeps the variable specific to the current site" do
      class_with_set = Class.new do
        include MultisiteClassVar
        multisite_class_var(:class_set) { Set.new }
      end

      conn.with_connection('default') do
        expect(class_with_set.class_set).to be_blank
        class_with_set.class_set << 'item0'
      end

      conn.with_connection('second') do
        expect(class_with_set.class_set).to be_blank
        class_with_set.class_set << 'item1'
      end

      conn.with_connection('default') do
        expect(class_with_set.class_set).to contain_exactly('item0')
      end

      conn.with_connection('second') do
        expect(class_with_set.class_set).to contain_exactly('item1')
      end

    end
  end

end
