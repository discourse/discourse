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
