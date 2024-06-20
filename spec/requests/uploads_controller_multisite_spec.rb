# frozen_string_literal: true

RSpec.describe UploadsController, type: %i[multisite request] do
  let!(:user) { Fabricate(:user) }
  let(:upload) { Fabricate(:upload_s3) }

  before do
    setup_s3
    SiteSetting.secure_uploads = true
    upload.update(secure: true)
    sign_in(user)
    freeze_time
  end

  it "redirects to the signed_url_for_path with the multisite DB name in the url" do
    get upload.short_path

    expect(response).to redirect_to(/#{RailsMultisite::ConnectionManagement.current_db}/)
  end
end
