# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Nodes::PostLikeChanged::V1 do
  fab!(:admin)
  fab!(:category)
  fab!(:other_category, :category)
  fab!(:topic) { Fabricate(:topic, category:) }
  fab!(:post) { Fabricate(:post, topic:) }
  fab!(:liker, :user)
  fab!(:tag)

  describe "#matches?" do
    it "filters changes, categories, tags, and topics" do
      SiteSetting.tagging_enabled = true
      topic.tags << tag
      trigger = described_class.from_event(:like_created, PostAction.new(post:, user: liker))

      expect(trigger.matches?(trigger_context({}))).to eq(true)
      expect(trigger.matches?(trigger_context(changes: ["unliked"]))).to eq(false)
      expect(trigger.matches?(trigger_context(category_ids: [other_category.id]))).to eq(false)
      expect(trigger.matches?(trigger_context(tag_names: ["missing"]))).to eq(false)
      expect(trigger.matches?(trigger_context(topic_ids: [topic.id + 1]))).to eq(false)
      expect(
        trigger.matches?(
          trigger_context(
            changes: ["liked"],
            category_ids: [category.id],
            tag_names: [tag.name],
            topic_ids: [topic.id],
          ),
        ),
      ).to eq(true)
    end
  end

  describe "event dispatch" do
    it "runs workflows as the liker when a post is liked and unliked" do
      graph = build_workflow_graph { |builder| builder.node "like", described_class.identifier }
      Fabricate(:discourse_workflows_workflow, created_by: admin, published: true, **graph)

      PostActionCreator.like(liker, post)
      PostActionDestroyer.destroy(liker, post, :like)

      jobs = Jobs::DiscourseWorkflows::ExecuteWorkflow.jobs.map { |job| job["args"].first }
      data = jobs.pluck("trigger_data")
      expect(data.pluck("change")).to eq(%w[liked unliked])
      expect(data.map { |payload| payload.dig("user", "id") }).to eq([liker.id, liker.id])
      expect(jobs.pluck("user_id")).to eq([liker.id, liker.id])
      expect(data).to all(match_node_output_schema(described_class))
    end
  end
end

RSpec.describe DiscourseWorkflows::Nodes::PostLikeChanged::V2 do
  fab!(:admin)
  fab!(:category)
  fab!(:other_category, :category)
  fab!(:topic) { Fabricate(:topic, category:) }
  fab!(:author, :user)
  fab!(:post) { Fabricate(:post, topic:, user: author) }
  fab!(:liker, :user)

  it "returns the post author as user and the liker as actor", :aggregate_failures do
    trigger = described_class.from_event(:like_created, PostAction.new(post:, user: liker))
    output = trigger.output

    expect(output[:user]).to include(id: author.id)
    expect(output[:actor]).to include(id: liker.id)
    expect(output).to match_node_output_schema(described_class)
  end

  it "stays registered but hidden, with its change filter" do
    expect(described_class).not_to be_palette_visible
    expect(described_class.properties).to have_key(:changes)
    expect(
      DiscourseWorkflows::Registry.find_node_type(described_class.identifier, version: "2.0"),
    ).to eq(described_class)
  end

  it "splits into one palette trigger per change", :aggregate_failures do
    {
      "trigger:post_liked" => [:like_created],
      "trigger:post_unliked" => [:like_destroyed],
    }.each do |identifier, events|
      node_class = DiscourseWorkflows::Registry.find_node_type(identifier)

      expect(node_class).to be_palette_visible
      expect(node_class).not_to be_deprecated
      expect(node_class.version).to eq("1.0")
      expect(node_class.i18n_scope).to eq("post_like_changed")
      expect(node_class.event_names).to eq(events)
      expect(node_class.properties.keys).to include(:category_ids, :tag_names, :topic_ids)
      expect(node_class.properties).not_to have_key(:changes)
    end
  end

  describe "Post liked and Post unliked" do
    before { DiscourseWorkflows::WorkflowDependency.clear_cache! }
    after { DiscourseWorkflows::WorkflowDependency.clear_cache! }

    let(:triggers) do
      {
        DiscourseWorkflows::Nodes::PostLiked::V1 => :like_created,
        DiscourseWorkflows::Nodes::PostUnliked::V1 => :like_destroyed,
      }
    end

    it "outputs the post, its topic, its author as user and the liker as actor",
       :aggregate_failures do
      triggers.each do |node_class, event_name|
        output = node_class.from_event(event_name, PostAction.new(post:, user: liker)).output

        expect(output.keys).to contain_exactly(:post, :topic, :user, :actor)
        expect(output).to include(
          post: include(id: post.id),
          topic: include(id: topic.id),
          user: include(id: author.id),
          actor: include(id: liker.id),
        )
        expect(output).to match_node_output_schema(node_class)
      end
    end

    it "only builds from its own event" do
      triggers.each do |node_class, event_name|
        other_event = (triggers.values - [event_name]).sole

        expect(
          node_class.from_event(other_event, PostAction.new(post:, user: liker)),
        ).not_to be_valid
      end
    end

    it "ignores a stray change filter but applies the topic filters", :aggregate_failures do
      triggers.each do |node_class, event_name|
        trigger = node_class.from_event(event_name, PostAction.new(post:, user: liker))

        stray_change = event_name == :like_created ? "unliked" : "liked"

        expect(trigger.matches?(trigger_context(changes: [stray_change]))).to eq(true)
        expect(trigger.matches?(trigger_context(category_ids: [other_category.id]))).to eq(false)
        expect(trigger.matches?(trigger_context(topic_ids: [topic.id + 1]))).to eq(false)
      end
    end

    it "reports a null user when the post's author was deleted" do
      post.update_columns(user_id: nil)

      triggers.each do |node_class, event_name|
        trigger = node_class.from_event(event_name, PostAction.new(post: post.reload, user: liker))

        expect(trigger).to be_valid
        expect(trigger.output[:user]).to be_nil
      end
    end

    it "runs workflows as the liker once per like change" do
      triggers.each_key do |node_class|
        graph =
          build_workflow_graph do |builder|
            builder.node node_class.identifier, node_class.identifier
          end
        Fabricate(:discourse_workflows_workflow, created_by: admin, published: true, **graph)
      end

      PostActionCreator.like(liker, post)
      PostActionDestroyer.destroy(liker, post, :like)

      jobs = Jobs::DiscourseWorkflows::ExecuteWorkflow.jobs.map { |job| job["args"].first }
      expect(jobs.pluck("user_id")).to eq([liker.id, liker.id])
      expect(jobs.first["trigger_data"]).to match_node_output_schema(
        DiscourseWorkflows::Nodes::PostLiked::V1,
      )
      expect(jobs.second["trigger_data"]).to match_node_output_schema(
        DiscourseWorkflows::Nodes::PostUnliked::V1,
      )
    end
  end
end
