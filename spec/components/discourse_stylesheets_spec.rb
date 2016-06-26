require 'rails_helper'
require_dependency 'sass/discourse_stylesheets'

describe DiscourseStylesheets do

  describe "compile" do
    it "can compile desktop bundle" do
      DiscoursePluginRegistry.stubs(:stylesheets).returns(["#{Rails.root}/spec/fixtures/scss/my_plugin.scss"])
      builder = described_class.new(:desktop)
      expect(builder.compile(force: true)).to include('my-plugin-thing')
      FileUtils.rm builder.stylesheet_fullpath
    end

    it "can compile mobile bundle" do
      DiscoursePluginRegistry.stubs(:mobile_stylesheets).returns(["#{Rails.root}/spec/fixtures/scss/my_plugin.scss"])
      builder = described_class.new(:mobile)
      expect(builder.compile(force: true)).to include('my-plugin-thing')
      FileUtils.rm builder.stylesheet_fullpath
    end

    it "can fallback when css is bad" do
      DiscoursePluginRegistry.stubs(:stylesheets).returns([
        "#{Rails.root}/spec/fixtures/scss/my_plugin.scss",
        "#{Rails.root}/spec/fixtures/scss/broken.scss"
      ])
      builder = described_class.new(:desktop)
      expect(builder.compile(force: true)).not_to include('my-plugin-thing')
      FileUtils.rm builder.stylesheet_fullpath
    end
  end

  describe "#digest" do
    before do
      described_class.expects(:max_file_mtime).returns(Time.new(2016, 06, 05, 12, 30, 0, 0))
    end

    it "should return a digest" do
      expect(described_class.new.digest).to eq('0e6c2e957cfc92ed60661c90ec3345198ccef887')
    end

    it "should include the cdn url when generating the digest" do
      GlobalSetting.expects(:cdn_url).returns('https://fastly.maxcdn.org')
      expect(described_class.new.digest).to eq('4995163b1232c54c8ed3b44200d803a90bc47613')
    end
  end
end
