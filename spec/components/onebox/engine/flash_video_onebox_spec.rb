require 'rails_helper'
require 'onebox/engine/flash_video_onebox'

describe Onebox::Engine::FlashVideoOnebox do
  before do
    @o = Onebox::Engine::FlashVideoOnebox.new('http://player.56.com/v_OTMyNTk1MzE.swf')
  end

  context "when SiteSetting.enable_flash_video_onebox is true" do
    before do
      SiteSetting.stubs(:enable_flash_video_onebox).returns(true)
    end

    it "generates a flash video" do
      expect(@o.to_html).to match_html(
        "<object width='100%' height='100%'><param name='http://player.56.com/v_OTMyNTk1MzE.swf' value='http://player.56.com/v_OTMyNTk1MzE.swf'><embed src='http://player.56.com/v_OTMyNTk1MzE.swf' width='100%' height='100%'></embed></object>" 
      )
    end
  end

  context "when SiteSetting.enable_flash_video_onebox is false" do
    before do
      SiteSetting.stubs(:enable_flash_video_onebox).returns(false)
    end

    it "generates a link" do
      expect(@o.to_html).to match_html(
        "<a href='http://player.56.com/v_OTMyNTk1MzE.swf'>http://player.56.com/v_OTMyNTk1MzE.swf</a>"
      )
    end
  end
end
