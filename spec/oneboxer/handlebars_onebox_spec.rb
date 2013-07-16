require 'spec_helper'

  H = Oneboxer::HandlebarsOnebox
describe Discourse::Oneboxer::HandlebarsOnebox do
  H = Discourse::Oneboxer::HandlebarsOnebox

  describe 'simple onebox' do
    it "is able to render image size when specified" do
      template = H.template_path('simple_onebox')
      result = H.generate_onebox(template, 'image_width' => 100, 'image_height' => 100, image: 'http://my.com/image.png')

      result.should =~ /width=/
      result.should =~ /height=/
    end
  end
end
