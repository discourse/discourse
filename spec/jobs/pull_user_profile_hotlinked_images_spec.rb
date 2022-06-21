# frozen_string_literal: true

describe Jobs::PullUserProfileHotlinkedImages do
  fab!(:user) { Fabricate(:user) }

  let(:image_url) { "http://wiki.mozilla.org/images/2/2e/Longcat1.png" }
  let(:png) { Base64.decode64("R0lGODlhAQABALMAAAAAAIAAAACAAICAAAAAgIAAgACAgMDAwICAgP8AAAD/AP//AAAA//8A/wD//wBiZCH5BAEAAA8ALAAAAAABAAEAAAQC8EUAOw==") }

  before do
    stub_request(:get, image_url).to_return(body: png, headers: { "Content-Type" => "image/png" })
    SiteSetting.download_remote_images_to_local = true
  end

  describe '#execute' do
    before do
      stub_image_size
    end

    it 'replaces images' do
      user.user_profile.update!(bio_raw: "![](#{image_url})")
      expect { Jobs::PullUserProfileHotlinkedImages.new.execute(user_id: user.id) }.to change { Upload.count }.by(1)
      expect(user.user_profile.reload.bio_cooked).to include(Upload.last.url)
    end

    it 'handles nil bio' do
      expect { Jobs::PullUserProfileHotlinkedImages.new.execute(user_id: user.id) }.to change { Upload.count }.by(0)
      expect(user.user_profile.reload.bio_cooked).to eq(nil)
    end
  end
end
