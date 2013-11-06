require 'spec_helper'
require 'oneboxer'
require 'oneboxer/flash_video_onebox'

describe Oneboxer::FlashVideoOnebox do
  before do
    @o = Oneboxer::FlashVideoOnebox.new('http://player.56.com/v_OTMyNTk1MzE.swf')
  end

  context "when SiteSetting.enable_flash_video_onebox is true" do
    before do
      SiteSetting.stubs(:enable_flash_video_onebox).returns(true)
    end

    it "generates a flash video" do
      expect(@o.onebox).to match_html(
        "<object width='100%' height='100%' wmode='opaque'><param name='http://player.56.com/v_OTMyNTk1MzE.swf' value='http://player.56.com/v_OTMyNTk1MzE.swf'><embed src='http://player.56.com/v_OTMyNTk1MzE.swf' width='100%' height='100%' wmode='opaque'></embed></object>"
      )
    end
  end

  context "when SiteSetting.enable_flash_video_onebox is false" do
    before do
      SiteSetting.stubs(:enable_flash_video_onebox).returns(false)
    end

    it "generates a link" do
      expect(@o.onebox).to match_html(
        "<a href='http://player.56.com/v_OTMyNTk1MzE.swf'>http://player.56.com/v_OTMyNTk1MzE.swf</a>"
      )
    end
  end
end
