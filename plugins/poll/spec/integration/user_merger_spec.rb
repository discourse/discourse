# frozen_string_literal: true

RSpec.describe UserMerger do
  fab!(:target_user) { Fabricate(:user, username: "galahad", email: "galahad@knights.com") }
  fab!(:source_user) { Fabricate(:user, username: "lancelot", email: "lancelot@knights.com") }
  fab!(:poll) { Fabricate(:poll) }

  it "deletes source_user vote if target_user already voted" do
    Fabricate(:poll_vote, poll: poll, user: target_user)
    Fabricate(:poll_vote, poll: poll, user: source_user)

    DiscourseEvent.trigger(:merging_users, source_user, target_user)

    expect(PollVote.where(user: source_user).count).to eq(0)
  end

  it "keeps only target_user vote if duplicate" do
    target_vote = Fabricate(:poll_vote, poll: poll, user: target_user)
    Fabricate(:poll_vote, poll: poll, user: source_user)

    DiscourseEvent.trigger(:merging_users, source_user, target_user)

    expect(PollVote.where(user: target_user).to_json).to eq([target_vote].to_json)
  end

  it "reassigns source_user vote to target_user if not duplicate" do
    Fabricate(:poll_vote, poll: poll, user: source_user)

    expect { DiscourseEvent.trigger(:merging_users, source_user, target_user) }.to change(
      PollVote.where(user: target_user),
      :count,
    ).from(0).to(1)
  end

  it "keeps any existing target_user votes" do
    Fabricate(:poll_vote, poll: poll, user: target_user)

    expect { DiscourseEvent.trigger(:merging_users, source_user, target_user) }.to not_change(
      PollVote.where(user: target_user),
      :count,
    )
  end
end
