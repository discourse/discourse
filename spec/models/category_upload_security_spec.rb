# frozen_string_literal: true

RSpec.describe Category do
  fab!(:admin)
  fab!(:other_user) do
    Fabricate(:user, username: "message-bus-user", email: "message-bus@example.com")
  end

  it "serializes category artwork with secure upload URLs when publishing /categories" do
    setup_s3
    SiteSetting.secure_uploads = true
    secure_upload = Fabricate(:secure_upload_s3, user: other_user)

    messages =
      MessageBus.track_publish("/categories") do
        Fabricate(:category, user: admin, name: "Published Artwork", uploaded_logo: secure_upload)
      end

    expect(messages.length).to eq(1)
    expect(messages.first.data[:categories].first[:uploaded_logo][:url]).to eq(
      UrlHelper.cook_url(secure_upload.url, secure: true),
    )
  end
end
