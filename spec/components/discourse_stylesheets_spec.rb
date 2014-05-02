require 'spec_helper'
require_dependency 'sass/discourse_stylesheets'

describe DiscourseStylesheets do

  describe "compile" do
    it "can compile desktop bundle" do
      DiscoursePluginRegistry.stubs(:stylesheets).returns(["#{Rails.root}/spec/fixtures/scss/my_plugin.scss"])
      builder = described_class.new(:desktop)
      builder.compile.should include('my-plugin-thing')
      FileUtils.rm builder.stylesheet_fullpath
    end

    it "can compile mobile bundle" do
      DiscoursePluginRegistry.stubs(:mobile_stylesheets).returns(["#{Rails.root}/spec/fixtures/scss/my_plugin.scss"])
      builder = described_class.new(:mobile)
      builder.compile.should include('my-plugin-thing')
      FileUtils.rm builder.stylesheet_fullpath
    end

    it "can fallback when css is bad" do
      DiscoursePluginRegistry.stubs(:stylesheets).returns([
        "#{Rails.root}/spec/fixtures/scss/my_plugin.scss",
        "#{Rails.root}/spec/fixtures/scss/broken.scss"
      ])
      builder = described_class.new(:desktop)
      builder.compile.should_not include('my-plugin-thing')
      FileUtils.rm builder.stylesheet_fullpath
    end
  end

end
