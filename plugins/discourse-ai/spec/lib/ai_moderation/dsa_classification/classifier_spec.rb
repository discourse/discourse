# frozen_string_literal: true

RSpec.describe DiscourseAi::AiModeration::DsaClassification::Classifier do
  fab!(:moderator)

  let(:decision_model) { instance_double(DecisionModel) }
  let(:classifier) { described_class.new(decision_model) }
  let(:result) do
    DiscourseAi::Decisions::Result.new(
      answers: [
        DiscourseAi::Decisions::Answers::Refusal.new(name: "community_rule"),
        DiscourseAi::Decisions::Answers::Refusal.new(name: "category"),
      ],
    )
  end

  before { enable_current_plugin }

  def model_input_for(reviewable)
    input = nil
    allow(decision_model).to receive(:decide) do |context, **_options|
      input = context
      result
    end

    classifier.suggest(reviewable, user: moderator)
    input
  end

  describe "#suggest" do
    it "sends deleted post content and distinct flag reasons to the model" do
      post = Fabricate(:post, raw: "You are all idiots for using spaces.")
      reviewable =
        Fabricate(
          :reviewable_flagged_post,
          target: post,
          topic: post.topic,
          target_created_by: post.user,
        )
      Fabricate(:reviewable_score, reviewable:, reviewable_score_type: ReviewableScore.types[:spam])
      Fabricate(
        :reviewable_score,
        reviewable:,
        reviewable_score_type: ReviewableScore.types[:inappropriate],
      )
      post.trash!
      reviewable.reload

      model_input = model_input_for(reviewable)
      input = JSON.parse(model_input)

      expect(input).to match(
        "title" => post.topic.title,
        "author" => post.user.username,
        "content" => post.raw,
        "flag_reasons" => a_collection_containing_exactly("Inappropriate", "Spam"),
      )
    end

    it "sends queued content without the original email" do
      reviewable = Fabricate(:reviewable_queued_post)
      reviewable.payload["title"] = "Buy cheap watches"

      model_input = model_input_for(reviewable)
      input = JSON.parse(model_input)

      expect(input).to eq(
        "title" => reviewable.payload["title"],
        "author" => reviewable.target_created_by.username,
        "content" => reviewable.payload["raw"],
      )
      expect(model_input).not_to include(reviewable.payload["raw_email"])
    end

    it "sends public profile fields without account details" do
      user = Fabricate(:user, name: "Spam Bot", email: "secret-spammer@example.com")
      user.user_profile.update!(
        bio_raw: "Cheap pills at my website.",
        website: "https://pills.example.com",
      )
      reviewable =
        Fabricate(:reviewable_user, target: user, payload: ReviewableUser.payload_for(user))

      model_input = model_input_for(reviewable)
      input = JSON.parse(model_input)

      expect(input).to eq(
        "author" => user.username,
        "profile" => {
          "name" => user.name,
          "bio" => user.user_profile.bio_raw,
          "website" => user.user_profile.website,
        },
      )
      expect(model_input).not_to include(user.email)
    end

    it "uses a plugin reviewable's existing serializer for its content" do
      message = Fabricate(:chat_message, message: "Buy cheap watches at my shop.")
      reviewable = Fabricate(:chat_reviewable_message, target: message)

      model_input = model_input_for(reviewable)
      input = JSON.parse(model_input)

      expect(input).to include("content" => message.cooked, "author" => message.user.username)
    end

    it "bounds the content sent to the model" do
      post = Fabricate(:post)
      post.update_columns(raw: "a" * 10_000)
      reviewable = Fabricate(:reviewable_flagged_post, target: post)

      expect(model_input_for(reviewable).length).to eq(described_class::MAX_CONTEXT_CHARS)
    end

    it "returns no suggestion when the reviewable exposes no content" do
      reviewable = Fabricate(:reviewable_user, payload: {})
      allow(decision_model).to receive(:decide)

      suggestion = classifier.suggest(reviewable, user: moderator)

      expect(suggestion).to have_attributes(community_rule: nil, category: nil)
      expect(decision_model).not_to have_received(:decide)
    end
  end
end
