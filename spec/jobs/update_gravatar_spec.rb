# frozen_string_literal: true

RSpec.describe Jobs::UpdateGravatar do
  fab!(:user) { Fabricate(:user) }
  let(:temp) { Tempfile.new("test") }
  fab!(:upload) { Fabricate(:upload, user: user) }
  let(:avatar) { user.create_user_avatar! }

  it "picks gravatar if system avatar is picked and gravatar was just downloaded" do
    temp.binmode
    # tiny valid png
    temp.write(
      Base64.decode64(
        "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAACklEQVR4nGMAAQAABQABDQottAAAAABJRU5ErkJggg==",
      ),
    )
    temp.rewind
    FileHelper.expects(:download).returns(temp)

    Jobs.run_immediately!

    expect(user.uploaded_avatar_id).to eq(nil)
    expect(user.user_avatar.gravatar_upload_id).to eq(nil)

    SiteSetting.automatically_download_gravatars = true

    user.refresh_avatar
    user.reload

    expect(user.uploaded_avatar_id).to_not eq(nil)
    expect(user.uploaded_avatar_id).to eq(user.user_avatar.gravatar_upload_id)

    temp.unlink
  end

  it "does not enqueue a job when user is missing their email" do
    user.primary_email.destroy
    user.reload

    expect(user.uploaded_avatar_id).to eq(nil)
    expect(user.user_avatar.gravatar_upload_id).to eq(nil)

    SiteSetting.automatically_download_gravatars = true

    expect { user.refresh_avatar }.not_to change { Jobs::UpdateGravatar.jobs.count }
    user.reload

    expect(user.uploaded_avatar_id).to eq(nil)
    expect(user.user_avatar.gravatar_upload_id).to eq(nil)
  end
end
