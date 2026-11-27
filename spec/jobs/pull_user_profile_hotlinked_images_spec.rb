# frozen_string_literal: true

RSpec.describe Jobs::PullUserProfileHotlinkedImages do
  fab!(:user)

  let(:image_url) { "http://wiki.mozilla.org/images/2/2e/Longcat1.png" }
  let(:png) do
    Base64.decode64(
      "R0lGODlhAQABALMAAAAAAIAAAACAAICAAAAAgIAAgACAgMDAwICAgP8AAAD/AP//AAAA//8A/wD//wBiZCH5BAEAAA8ALAAAAAABAAEAAAQC8EUAOw==",
    )
  end

  before do
    stub_request(:get, image_url).to_return(body: png, headers: { "Content-Type" => "image/png" })
    SiteSetting.download_remote_images_to_local = true
  end

  describe "#execute" do
    before { stub_image_size }

    it "replaces images" do
      user.user_profile.update!(bio_raw: "![](#{image_url})")
      expect { Jobs::PullUserProfileHotlinkedImages.new.execute(user_id: user.id) }.to change {
        Upload.count
      }.by(1)
      expect(user.user_profile.reload.bio_cooked).to include(Upload.last.url)
    end

    it "preserves a moderator's removal while an image download is in progress" do
      profile = user.user_profile
      profile.update!(bio_raw: "Reported biography ![](#{image_url})")
      report = Fabricate(:reviewable_flagged_profile, target: profile)
      moderator = Fabricate(:moderator)
      stub_request(:get, image_url).to_return do
        report.perform(moderator, :remove_profile_content)
        { body: png, headers: { "Content-Type" => "image/png" } }
      end

      described_class.new.execute(user_id: user.id)

      expect(report.reload).to be_approved
      expect(profile.reload).to have_attributes(bio_raw: nil, bio_cooked: nil)
    end

    it "does not copy a secure upload whose URL sits outside the site's subfolder" do
      enable_secure_uploads
      upload = Fabricate(:secure_upload_s3, secure: true)
      FileStore::S3Store.any_instance.stubs(:signed_url_for_path).returns(image_url)
      FileStore::S3Store.any_instance.stubs(:store_upload).returns(upload.url)

      secure_url = Discourse.base_url + Upload.secure_uploads_url_from_upload_url(upload.url)
      set_subfolder "/forum"
      user.user_profile.update!(bio_raw: "<img src='#{secure_url}'>")

      expect { Jobs::PullUserProfileHotlinkedImages.new.execute(user_id: user.id) }.not_to change {
        Upload.count
      }
    end

    it "handles nil bio" do
      expect { Jobs::PullUserProfileHotlinkedImages.new.execute(user_id: user.id) }.not_to change {
        Upload.count
      }
      expect(user.user_profile.reload.bio_cooked).to eq(nil)
    end
  end
end
