# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Nodes::PostLifecycle do
  subject(:trigger) { klass.new(post, {}, actor) }

  fab!(:category)
  fab!(:tag) { Fabricate(:tag, name: "availability") }
  fab!(:topic) { Fabricate(:topic, category: category) }
  fab!(:first_post) { Fabricate(:post, topic: topic, raw: "Topic opener") }
  fab!(:post) { Fabricate(:post, topic: topic, raw: "Out next week") }
  fab!(:small_action) { Fabricate(:post, topic: topic, post_type: Post.types[:small_action]) }
  fab!(:actor, :admin)

  let(:klass) { DiscourseWorkflows::Nodes::PostDestroyed::V1 }

  before do
    SiteSetting.tagging_enabled = true
    topic.tags << tag
  end

  def trigger_context(parameters)
    DiscourseWorkflows::TriggerNodeContext.new({ "parameters" => parameters })
  end

  describe "#valid?" do
    it "accepts a regular post, including once it is deleted" do
      expect(trigger).to be_valid

      PostDestroyer.new(actor, post).destroy

      expect(klass.new(post.reload, {}, actor)).to be_valid
    end

    it "rejects a missing post, a non-regular post, and workflow-driven changes",
       :aggregate_failures do
      expect(klass.new(nil, {}, actor)).not_to be_valid
      expect(klass.new(small_action, {}, actor)).not_to be_valid
      expect(klass.new(post, { skip_workflows: true }, actor)).not_to be_valid
    end
  end

  describe "#output" do
    it "returns the post, its topic, and the acting user", :aggregate_failures do
      output = trigger.output

      expect(output[:post]).to include(
        id: post.id,
        raw: post.raw,
        topic_id: topic.id,
        username: post.user.username,
        category_id: category.id,
        tags: ["availability"],
      )
      expect(output[:topic]).to include(id: topic.id, title: topic.title)
      expect(output[:user]).to include(id: actor.id, username: actor.username)
      expect(output).to match_node_output_schema(klass)
    end

    it "keeps topic-derived post fields when the topic went down with the post",
       :aggregate_failures do
      PostDestroyer.new(actor, first_post).destroy

      output = klass.new(first_post.reload, {}, actor).output

      expect(output[:post]).to include(
        topic_title: topic.title,
        category_id: category.id,
        post_url: Post.url(topic.slug, topic.id, first_post.post_number),
        tags: ["availability"],
      )
    end
  end

  describe "#matches?" do
    it "matches the configured category and tags" do
      expect(
        trigger.matches?(
          trigger_context("category_ids" => [category.id.to_s], "tag_names" => [tag.name]),
        ),
      ).to eq(true)
    end

    it "excludes personal messages unless they are asked for", :aggregate_failures do
      pm_trigger = klass.new(Fabricate(:private_message_post), {}, actor)

      expect(pm_trigger.matches?(trigger_context({}))).to eq(false)
      expect(pm_trigger.matches?(trigger_context("topic_type" => "personal_messages"))).to eq(true)
      expect(trigger.matches?(trigger_context("topic_type" => "personal_messages"))).to eq(false)
    end
  end
end
