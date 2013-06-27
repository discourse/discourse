# encoding: utf-8

require 'spec_helper'
require 'oneboxer'
require 'oneboxer/android_app_store_onebox'

describe Oneboxer::AndroidAppStoreOnebox do
  before(:each) do
    @o = Oneboxer::AndroidAppStoreOnebox.new("https://play.google.com/store/apps/details?id=com.moosoft.parrot")
    FakeWeb.register_uri(:get, @o.translate_url, response: fixture_file('oneboxer/android.response'))
  end

  it "generates the expected onebox for Android App Store" do
    @o.onebox.should match_html expected_android_app_store_result
  end

private
  def expected_android_app_store_result
    <<EXPECTED
<div class='onebox-result'>
    <div class='source'>
      <div class='info'>
        <a href='https://play.google.com/store/apps/details?id=com.moosoft.parrot' class="track-link" target="_blank">
          <img class='favicon' src="/assets/favicons/google_play.png"> play.google.com
        </a>
      </div>
    </div>
  <div class='onebox-result-body'>
    <img src="https://lh5.ggpht.com/wrYYVu74XNUu2WHk0aSZEqgdCDCNti9Fl0_dJnhgR6jY04ajQgVg5ABMatfcTDsB810=w124" class="thumbnail">
    <h3><a href="https://play.google.com/store/apps/details?id=com.moosoft.parrot" target="_blank">Talking Parrot</a></h3>
    
      Listen to the parrot repeat what you say. A Fun application for all ages. Upgrade to Talking Parrot Pro to save sounds, set them as your ringtone and control recording. 
 Press the MENU button to access the settings where you can change the record time and repeat count. 
 This app uses anonymous usage stats to understand and improve performance. 
 Comments and feedback welcome. 
  </div>
  <div class='clearfix'></div>
</div>
EXPECTED
  end
end
