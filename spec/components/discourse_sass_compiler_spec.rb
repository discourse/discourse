require 'rails_helper'
require_dependency 'sass/discourse_sass_compiler'

describe DiscourseSassCompiler do

  let(:test_scss) { "body { p {color: blue;} }\n@import 'common/foundation/variables';\n@import 'plugins';" }

  describe '#compile' do
    it "compiles scss" do
      DiscoursePluginRegistry.stubs(:stylesheets).returns(["#{Rails.root}/spec/fixtures/scss/my_plugin.scss"])
      css = described_class.compile(test_scss, "test")
      expect(css).to include("color")
      expect(css).to include('my-plugin-thing')
    end

    it "raises error for invalid scss" do
      expect {
        described_class.compile("this isn't valid scss", "test")
      }.to raise_error(Sass::SyntaxError)
    end

    it "doesn't load theme or plugins in safe mode" do
      ColorScheme.expects(:enabled).never
      DiscoursePluginRegistry.stubs(:stylesheets).returns(["#{Rails.root}/spec/fixtures/scss/my_plugin.scss"])
      css = described_class.compile(test_scss, "test", safe: true)
      expect(css).not_to include('my-plugin-thing')
    end
  end

end
