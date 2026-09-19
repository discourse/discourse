# frozen_string_literal: true

RSpec.describe DiscourseChatIntegration::ChatIntegrationReferencePost do
  fab!(:topic)
  fab!(:first_post) { Fabricate(:post, topic: topic) }
  let!(:context) do
    {
      "user" => Fabricate(:user),
      "topic" => topic,
      # every rule will add a kind and their context params
    }
  end

  describe "when no topic is provided" do
    subject(:post) do
      described_class.new(user: Discourse.system_user, kind: :workflow, raw: "A custom message")
    end

    it "provides standalone site context", :aggregate_failures do
      expect(post.id).to be_nil
      expect(post.user).to eq(Discourse.system_user)
      expect(post.topic.id).to be_nil
      expect(post.topic.title).to eq(SiteSetting.title)
      expect(post.topic.category).to be_nil
      expect(post.topic.tags).to be_empty
      expect(post.topic.posts).to be_empty
      expect(post.topic.custom_fields).to be_empty
      expect(post.full_url).to eq(Discourse.base_url)
      expect(post.excerpt).to eq("A custom message")
      expect(post).to be_is_first_post
    end

    it "can be formatted by every chat-integration provider" do
      messages = [
        DiscourseChatIntegration::Provider::SlackProvider.slack_message(post, "#alerts", ""),
        DiscourseChatIntegration::Provider::DiscordProvider.generate_discord_message(post),
        DiscourseChatIntegration::Provider::TelegramProvider.message_text(post),
        DiscourseChatIntegration::Provider::MattermostProvider.mattermost_message(post, "alerts"),
        DiscourseChatIntegration::Provider::MatrixProvider.generate_matrix_message(post),
        DiscourseChatIntegration::Provider::RocketchatProvider.rocketchat_message(post, "#alerts"),
        DiscourseChatIntegration::Provider::WebexProvider.get_message(post),
        DiscourseChatIntegration::Provider::GuildedProvider.generate_guilded_message(post),
        DiscourseChatIntegration::Provider::GroupmeProvider.generate_groupme_message(post),
        DiscourseChatIntegration::Provider::ZulipProvider.generate_zulip_message(
          post,
          "alerts",
          "subject",
        ),
        DiscourseChatIntegration::Provider::GitterProvider.gitter_message(post),
        DiscourseChatIntegration::Provider::GoogleProvider.get_message(post),
        DiscourseChatIntegration::Provider::TeamsProvider.get_message(post),
        DiscourseChatIntegration::Provider::PowerAutomateProvider.get_message(post),
      ]

      expect(messages).to all(be_present)
    end
  end

  describe "when creating when topic tags change" do
    before do
      context["kind"] = DiscourseAutomation::Triggers::TOPIC_TAGS_CHANGED
      context["added_tags"] = %w[tag1 tag2]
      context["removed_tags"] = %w[tag3 tag4]
    end

    it "creates a post with the correct .raw" do
      post =
        described_class.new(
          user: context["user"],
          topic: context["topic"],
          kind: context["kind"],
          context: {
            "added_tags" => context["added_tags"],
            "removed_tags" => context["removed_tags"],
          },
        )
      expect(post.raw).to eq("Added #tag1, #tag2 and removed #tag3, #tag4")
    end

    it "has a working .excerpt" do
      post =
        described_class.new(
          user: context["user"],
          topic: context["topic"],
          kind: context["kind"],
          context: {
            "added_tags" => context["added_tags"],
            "removed_tags" => context["removed_tags"],
          },
        )
      expect(post.excerpt).to eq("Added #tag1, #tag2 and removed #tag3, #tag4")
    end

    it "has a working .full_url" do
      post =
        described_class.new(
          user: context["user"],
          topic: context["topic"],
          kind: context["kind"],
          context: {
            "added_tags" => context["added_tags"],
            "removed_tags" => context["removed_tags"],
          },
        )
      expect(post.full_url).to eq(topic.posts.first.full_url)

      new_topic = Fabricate(:topic)
      post =
        described_class.new(
          user: context["user"],
          topic: new_topic,
          kind: context["kind"],
          context: {
            "added_tags" => context["added_tags"],
            "removed_tags" => context["removed_tags"],
          },
        )
      expect(post.full_url).to eq(new_topic.url)
    end

    it "has a working .is_first_post?" do
      post =
        described_class.new(
          user: context["user"],
          topic: context["topic"],
          kind: context["kind"],
          context: {
            "added_tags" => context["added_tags"],
            "removed_tags" => context["removed_tags"],
          },
        )
      expect(post.is_first_post?).to eq(false) # we had a post already

      new_topic = Fabricate(:topic)
      post =
        described_class.new(
          user: context["user"],
          topic: new_topic,
          kind: context["kind"],
          context: {
            "added_tags" => context["added_tags"],
            "removed_tags" => context["removed_tags"],
          },
        )
      expect(post.is_first_post?).to eq(true)
    end

    it "has a working .id" do
      new_topic = Fabricate(:topic)
      post =
        described_class.new(
          user: context["user"],
          topic: new_topic,
          kind: context["kind"],
          context: {
            "added_tags" => context["added_tags"],
            "removed_tags" => context["removed_tags"],
          },
        )
      expect(post.id).to eq(new_topic.id)

      post =
        described_class.new(
          user: context["user"],
          topic: context["topic"],
          kind: context["kind"],
          context: {
            "added_tags" => context["added_tags"],
            "removed_tags" => context["removed_tags"],
          },
        )
      expect(post.id).to eq(first_post.id)
    end
  end
end
