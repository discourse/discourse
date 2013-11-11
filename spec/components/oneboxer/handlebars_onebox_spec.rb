require 'spec_helper'
require 'oneboxer'
require 'oneboxer/handlebars_onebox'

describe Oneboxer::HandlebarsOnebox do
  H = Oneboxer::HandlebarsOnebox

  describe 'simple onebox' do
    it "is able to render image size when specified" do
      template = H.template_path('simple_onebox')
      result = H.generate_onebox(template, 'image_width' => 100, 'image_height' => 100, image: 'http://my.com/image.png')

      result.should =~ /width=/
      result.should =~ /height=/
    end
  end
end
