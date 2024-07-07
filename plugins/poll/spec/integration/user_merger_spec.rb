# frozen_string_literal: true

RSpec.describe UserMerger do
  fab!(:target_user) { Fabricate(:user, username: "galahad", email: "galahad@knights.com") }
  fab!(:source_user) { Fabricate(:user, username: "lancelot", email: "lancelot@knights.com") }

  fab!(:poll_regular) { Fabricate(:poll) }
  fab!(:poll_regular_option1) { Fabricate(:poll_option, poll: poll_regular, html: "Option 1") }
  fab!(:poll_regular_option2) { Fabricate(:poll_option, poll: poll_regular, html: "Option 2") }

  fab!(:poll_multiple) { Fabricate(:poll) }
  fab!(:poll_multiple_optionA) { Fabricate(:poll_option, poll: poll_multiple, html: "Option A") }
  fab!(:poll_multiple_optionB) { Fabricate(:poll_option, poll: poll_multiple, html: "Option B") }
  fab!(:poll_multiple_optionC) { Fabricate(:poll_option, poll: poll_multiple, html: "Option C") }

  fab!(:poll_ranked_choice) { Fabricate(:poll) }
  fab!(:poll_ranked_choice_optionA) do
    Fabricate(:poll_option, poll: poll_ranked_choice, html: "Option A")
  end
  fab!(:poll_ranked_choice_optionB) do
    Fabricate(:poll_option, poll: poll_ranked_choice, html: "Option B")
  end
  fab!(:poll_ranked_choice_optionC) do
    Fabricate(:poll_option, poll: poll_ranked_choice, html: "Option C")
  end

  it "will end up with no votes from source user" do
    Fabricate(:poll_vote, poll: poll_regular, user: source_user, poll_option: poll_regular_option2)
    Fabricate(
      :poll_vote,
      poll: poll_multiple,
      user: source_user,
      poll_option: poll_multiple_optionB,
    )

    DiscourseEvent.trigger(:merging_users, source_user, target_user)

    expect(PollVote.where(user: source_user).count).to eq(0)
  end

  it "will not use source user's vote if target_user already voted in the same poll" do
    Fabricate(:poll_vote, poll: poll_regular, user: target_user, poll_option: poll_regular_option1)
    Fabricate(:poll_vote, poll: poll_regular, user: source_user, poll_option: poll_regular_option2)

    Fabricate(
      :poll_vote,
      poll: poll_multiple,
      user: target_user,
      poll_option: poll_multiple_optionA,
    )
    Fabricate(
      :poll_vote,
      poll: poll_multiple,
      user: source_user,
      poll_option: poll_multiple_optionB,
    )
    Fabricate(
      :poll_vote,
      poll: poll_multiple,
      user: source_user,
      poll_option: poll_multiple_optionC,
    )

    DiscourseEvent.trigger(:merging_users, source_user, target_user)

    expect(PollVote.where(user: target_user).pluck(:poll_option_id)).to contain_exactly(
      poll_multiple_optionA.id,
      poll_regular_option1.id,
    )
  end

  it "will use source user's vote if poll was the ranked choice type" do
    Fabricate(
      :poll_vote,
      poll: poll_ranked_choice,
      user: source_user,
      poll_option: poll_ranked_choice_optionA,
      rank: 2,
    )

    DiscourseEvent.trigger(:merging_users, source_user, target_user)

    expect(PollVote.where(user: target_user).pluck(:poll_option_id)).to contain_exactly(
      poll_ranked_choice_optionA.id,
    )
  end

  it "reassigns source_user vote to target_user if target user has never voted in the poll" do
    Fabricate(:poll_vote, poll: poll_regular, user: source_user)

    expect { DiscourseEvent.trigger(:merging_users, source_user, target_user) }.to change(
      PollVote.where(user: target_user),
      :count,
    ).from(0).to(1)
  end

  it "keeps any existing target_user votes" do
    Fabricate(:poll_vote, poll: poll_regular, user: target_user)

    expect { DiscourseEvent.trigger(:merging_users, source_user, target_user) }.to not_change(
      PollVote.where(user: target_user),
      :count,
    )
  end
end
