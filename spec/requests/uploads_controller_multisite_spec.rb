# frozen_string_literal: true

require 'rails_helper'

describe UploadsController do
  let!(:user) { Fabricate(:user) }

  describe "#show_short" do
    describe "s3 store" do
      let(:upload) { Fabricate(:upload_s3) }

      before do
        SiteSetting.enable_s3_uploads = true
        SiteSetting.s3_access_key_id = "fakeid7974664"
        SiteSetting.s3_secret_access_key = "fakesecretid7974664"
      end

      context "when upload is secure and secure media enabled" do
        before do
          SiteSetting.secure_media = true
          upload.update(secure: true)
          stub_request(:head, "https://#{SiteSetting.s3_upload_bucket}.s3.amazonaws.com/")
        end
        context "when running on a multisite connection", type: :multisite do
          it "redirects to the signed_url_for_path with the multisite DB name in the url" do
            sign_in(user)
            freeze_time
            get upload.short_path
            expect(response.body).to include(RailsMultisite::ConnectionManagement.current_db)
          end
        end
      end
    end
  end
end
