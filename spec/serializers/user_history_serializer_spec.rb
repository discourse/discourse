# frozen_string_literal: true

RSpec.describe UserHistorySerializer do
  fab!(:admin)
  fab!(:user)

  it "includes the scheduled expiry" do
    freeze_time
    history =
      Fabricate(
        :user_history,
        action: UserHistory.actions[:suspend_user],
        target_user: user,
        expires_at: 2.days.from_now,
      )

    json = described_class.new(history, scope: admin.guardian, root: false).as_json

    expect(json[:expires_at]).to eq_time(history.expires_at)
  end

  it "leaves expiry unknown for logs without a snapshot" do
    user.update!(suspended_till: 2.days.from_now)
    history =
      Fabricate(:user_history, action: UserHistory.actions[:suspend_user], target_user: user)

    json = described_class.new(history, scope: admin.guardian, root: false).as_json

    expect(json).to have_key(:expires_at)
    expect(json[:expires_at]).to be_nil
  end

  it "redacts expiry when the log content is not visible" do
    post = Fabricate(:private_message_post)
    history =
      Fabricate(
        :user_history,
        action: UserHistory.actions[:silence_user],
        target_user: user,
        post: post,
        expires_at: 2.days.from_now,
      )

    json = described_class.new(history, scope: Fabricate(:moderator).guardian, root: false).as_json

    expect(json[:expires_at]).to be_nil
  end
end
