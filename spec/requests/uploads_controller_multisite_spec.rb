# frozen_string_literal: true

RSpec.describe UploadsController, type: %i[multisite request] do
  let!(:user) { Fabricate(:user) }
  let(:upload) { Fabricate(:upload_s3) }

  before do
    setup_s3
    SiteSetting.secure_uploads = true
    upload.update(secure: true)
  end

  it "redirects to the signed_url_for_path with the multisite DB name in the url" do
    sign_in(user)
    freeze_time
    get upload.short_path

    expect(response.body).to include(RailsMultisite::ConnectionManagement.current_db)
  end
end
