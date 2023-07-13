# frozen_string_literal: true

def serialize_option(option, user)
  PollOptionSerializer.new(
    option,
    root: false,
    scope: {
      can_see_results: poll.can_see_results?(user),
    },
  )
end

RSpec.describe PollOptionSerializer do
  let(:voter) { Fabricate(:user) }
  let(:poll) { post.polls.first }

  before { poll.poll_votes.create!(poll_option_id: poll.poll_options.first.id, user_id: voter.id) }

  context "when poll results are public" do
    let(:post) { Fabricate(:post, raw: "[poll]\n- A\n- B\n[/poll]") }

    context "when user is not staff" do
      let(:user) { Fabricate(:user) }

      it "include votes" do
        serializer = serialize_option(poll.poll_options.first, user)

        expect(serializer.include_votes?).to eq(true)
      end
    end
  end

  context "when poll results are staff only" do
    let(:post) { Fabricate(:post, raw: "[poll results=staff_only]\n- A\n- B\n[/poll]") }

    context "when user is not staff" do
      let(:user) { Fabricate(:user) }

      it "doesn’t include votes" do
        serializer = serialize_option(poll.poll_options.first, user)

        expect(serializer.include_votes?).to eq(false)
      end
    end

    context "when user is staff" do
      let(:admin) { Fabricate(:admin) }

      it "includes votes" do
        serializer = serialize_option(poll.poll_options.first, admin)

        expect(serializer.include_votes?).to eq(true)
      end
    end
  end
end
