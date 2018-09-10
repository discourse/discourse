require 'rails_helper'

RSpec.describe Jobs::FixOutOfSyncUserUploadedAvatar do
  it 'should fix out of sync user uploaded avatars' do
    user_with_custom_upload = Fabricate(:user)
    custom_upload1 = Fabricate(:upload, user: user_with_custom_upload)
    gravatar_upload1 = Fabricate(:upload, user: user_with_custom_upload)
    user_with_custom_upload.update!(uploaded_avatar: custom_upload1)

    user_with_custom_upload.user_avatar.update!(
      custom_upload: custom_upload1,
      gravatar_upload: gravatar_upload1
    )

    user_out_of_sync = Fabricate(:user)
    custom_upload2 = Fabricate(:upload, user: user_out_of_sync)
    gravatar_upload2 = Fabricate(:upload, user: user_out_of_sync)
    prev_gravatar_upload = Fabricate(:upload, user: user_out_of_sync)

    prev_gravatar_upload.destroy!
    user_out_of_sync.update!(uploaded_avatar_id: prev_gravatar_upload.id)

    user_out_of_sync.user_avatar.update!(
      custom_upload: custom_upload2,
      gravatar_upload: gravatar_upload2
    )

    user_without_uploaded_avatar = Fabricate(:user)
    gravatar_upload3 = Fabricate(:upload, user: user_without_uploaded_avatar)

    user_without_uploaded_avatar.user_avatar.update!(
      gravatar_upload: gravatar_upload3
    )

    described_class.new.execute_onceoff({})

    expect(user_with_custom_upload.reload.uploaded_avatar).to eq(custom_upload1)
    expect(user_out_of_sync.reload.uploaded_avatar).to eq(gravatar_upload2)

    expect(user_without_uploaded_avatar.reload.uploaded_avatar)
      .to eq(nil)

  end
end
