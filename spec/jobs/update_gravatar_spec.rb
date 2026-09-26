# frozen_string_literal: true

RSpec.describe Jobs::UpdateGravatar do
  fab!(:user)

  it "preserves a picture chosen while Gravatar is downloading" do
    upload = Fabricate(:upload, user: user)
    stub_request(:get, %r{https://www.gravatar.com/avatar/}).to_return do
      user.update!(uploaded_avatar_id: upload.id)
      { body: File.binread(file_from_fixtures("logo.png")) }
    end

    described_class.new.execute(user_id: user.id, avatar_id: user.user_avatar.id)

    expect(user.reload.uploaded_avatar_id).to eq(upload.id)
  end

  it "selects a downloaded or cached Gravatar when the system avatar is selected" do
    stub_request(:get, %r{https://www.gravatar.com/avatar/}).to_return(
      body: File.binread(file_from_fixtures("logo.png")),
    )

    Jobs.run_immediately!

    expect(user.uploaded_avatar_id).to eq(nil)
    expect(user.user_avatar.gravatar_upload_id).to eq(nil)

    SiteSetting.automatically_download_gravatars = true

    user.refresh_avatar
    user.reload

    expect(user.uploaded_avatar_id).to_not eq(nil)
    expect(user.uploaded_avatar_id).to eq(user.user_avatar.gravatar_upload_id)

    cached_gravatar_id = user.user_avatar.gravatar_upload_id
    user.update!(uploaded_avatar_id: nil)
    stub_request(:get, %r{https://www.gravatar.com/avatar/}).to_return(
      status: Rack::Utils::SYMBOL_TO_STATUS_CODE[:not_found],
    )

    described_class.new.execute(user_id: user.id, avatar_id: user.user_avatar.id)

    expect(user.reload.uploaded_avatar_id).to eq(cached_gravatar_id)
  end
end
