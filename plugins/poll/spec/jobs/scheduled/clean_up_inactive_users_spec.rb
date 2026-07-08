# frozen_string_literal: true

describe Jobs::CleanUpInactiveUsers do
  before { SiteSetting.clean_up_inactive_users_after_days = 4 }

  def inactive_user
    Fabricate(
      :user,
      created_at: 5.days.ago,
      last_seen_at: 5.days.ago,
      trust_level: TrustLevel.levels[:newuser],
    )
  end

  it "does not delete users who have cast poll votes" do
    user = inactive_user
    poll = Fabricate(:poll)
    option = Fabricate(:poll_option, poll: poll)
    Fabricate(:poll_vote, poll: poll, poll_option: option, user: user)

    expect { described_class.new.execute({}) }.not_to change { User.count }
    expect(User.exists?(user.id)).to eq(true)
  end

  it "deletes inactive users who have never voted in a poll" do
    user = inactive_user

    expect { described_class.new.execute({}) }.to change { User.count }.by(-1)
    expect(User.exists?(user.id)).to eq(false)
  end
end
