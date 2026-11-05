# frozen_string_literal: true

RSpec.describe DiscourseAi::AiModeration::DsaClassification::State do
  subject(:state) { described_class.new(reviewable).to_s }

  before { enable_current_plugin }

  describe "#to_s" do
    context "with a flagged post" do
      fab!(:topic) { Fabricate(:topic, title: "A heated debate about tabs") }
      fab!(:post) { Fabricate(:post, topic:, raw: "You are all idiots for using spaces.") }
      fab!(:reviewable) do
        Fabricate(:reviewable_flagged_post, target: post, topic:, target_created_by: post.user)
      end

      it "describes the flag reasons and the flagged post" do
        expect(state).to eq(<<~TEXT.strip)
          Flagged as: Inappropriate

          Author: #{post.user.username}
          Topic title: #{topic.title}
          Post:
          #{post.raw}
        TEXT
      end

      it "still describes the post after it was deleted" do
        post.trash!

        expect(state).to include("Post:\n#{post.raw}")
      end

      it "lists each flag reason once" do
        Fabricate(
          :reviewable_score,
          reviewable:,
          reviewable_score_type: ReviewableScore.types[:spam],
        )
        Fabricate(
          :reviewable_score,
          reviewable:,
          reviewable_score_type: ReviewableScore.types[:inappropriate],
        )

        expect(state.lines.first).to eq("Flagged as: Inappropriate, Spam\n")
      end

      it "truncates long content" do
        post.update_columns(raw: "a" * 10_000)

        expect(state.split("\n\n", 2).last.length).to eq(described_class::MAX_CONTENT_CHARS)
      end
    end

    context "with a queued post" do
      fab!(:reviewable) do
        Fabricate(
          :reviewable_queued_post_topic,
          payload: {
            title: "Buy cheap watches",
            raw: "Visit my shop for deals.",
          },
        )
      end

      it "describes the queued title and raw with its author" do
        expect(state).to eq(<<~TEXT.strip)
          Author: #{reviewable.target_created_by.username}
          Topic title: Buy cheap watches
          Post:
          Visit my shop for deals.
        TEXT
      end
    end

    context "with a user" do
      fab!(:user) { Fabricate(:user, name: "Spam Bot", email: "secret-spammer@example.com") }
      fab!(:reviewable) { Fabricate(:reviewable_user, target: user) }

      before do
        user.user_profile.update!(
          bio_raw: "Cheap pills at my website.",
          location: "Nowhere",
          website: "https://pills.example.com",
        )
      end

      it "describes the public profile without the email" do
        expect(state).to eq(<<~TEXT.strip)
          Username: #{user.username}
          Name: Spam Bot
          Location: Nowhere
          Website: https://pills.example.com
          Bio:
          Cheap pills at my website.
        TEXT
        expect(state).not_to include(user.email)
      end
    end
  end
end
