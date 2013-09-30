require 'spec_helper'
require 'oneboxer'
require 'oneboxer/handlebars_onebox'

describe Oneboxer::HandlebarsOnebox do

  describe 'simple onebox' do
    H = Oneboxer::HandlebarsOnebox

    it "is able to render image size when specified" do
      template = H.template_path('simple_onebox')
      result = H.generate_onebox(template, 'image_width' => 100, 'image_height' => 100, image: 'http://my.com/image.png')

      result.should =~ /width=/
      result.should =~ /height=/
    end

    class SimpleOnebox < Oneboxer::HandlebarsOnebox
      favicon 'stackexchange.png'

      def parse(html)
        { testing: true }
      end
    end

    it "does not use fingerprint on favicons" do
      onebox = SimpleOnebox.new "http://domain.com"
      onebox.stubs(:fetch_html).returns("")
      ActionController::Base.helpers.expects(:asset_path).with('favicons/stackexchange.png', digest: false)
      result = onebox.onebox
    end

  end

end
