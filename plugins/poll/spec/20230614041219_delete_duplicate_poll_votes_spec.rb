# frozen_string_literal: true

require Rails.root.join("plugins/poll/db/migrate/20230614041219_delete_duplicate_poll_votes.rb")

describe DeleteDuplicatePollVotes do
  subject(:up) { described_class.new.up }

  fab!(:user) { Fabricate(:user, username: "galahad", email: "galahad@knights.com") }

  fab!(:poll_regular) { Fabricate(:poll_regular) }
  fab!(:poll_regular_option1) { Fabricate(:poll_option, poll: poll_regular, html: "Option 1") }
  fab!(:poll_regular_option2) { Fabricate(:poll_option, poll: poll_regular, html: "Option 2") }

  fab!(:poll_multiple) { Fabricate(:poll_multiple) }
  fab!(:poll_multiple_optionA) { Fabricate(:poll_option, poll: poll_multiple, html: "Option A") }
  fab!(:poll_multiple_optionB) { Fabricate(:poll_option, poll: poll_multiple, html: "Option B") }

  it "deletes the older duplicate poll vote for regular polls" do
    Fabricate(
      :poll_vote,
      poll: poll_regular,
      user: user,
      poll_option: poll_regular_option1,
      created_at: 2.years.ago,
    )
    Fabricate(
      :poll_vote,
      poll: poll_regular,
      user: user,
      poll_option: poll_regular_option2,
      created_at: 1.year.ago,
    )

    expect { up }.to change { PollVote.count }.from(2).to(1)
    expect(PollVote.first.poll_option).to eq(poll_regular_option2)
  end

  it "keeps non-duplicates" do
    Fabricate(:poll_vote, poll: poll_regular, user: user, poll_option: poll_regular_option1)

    expect { up }.not_to change { PollVote.count }
  end

  it "keeps votes on polls with type multiple" do
    Fabricate(:poll_vote, poll: poll_multiple, user: user, poll_option: poll_multiple_optionA)
    Fabricate(:poll_vote, poll: poll_multiple, user: user, poll_option: poll_multiple_optionB)

    expect { up }.not_to change { PollVote.count }
  end
end
