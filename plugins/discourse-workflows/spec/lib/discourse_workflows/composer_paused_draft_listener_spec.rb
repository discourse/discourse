# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::ComposerPausedDraftListener do
  fab!(:admin)
  fab!(:user) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:topic)

  let(:configuration) { { "fire_on" => "draft_saved", "phrases" => ["Magic words", "food stand"] } }
  let!(:workflow) do
    graph =
      build_workflow_graph do |g|
        g.node "trigger-1", "trigger:composer_paused", configuration: configuration
      end
    Fabricate(:discourse_workflows_workflow, created_by: admin, published: true, **graph)
  end

  before { DiscourseWorkflows::WorkflowDependency.clear_cache! }

  def save_draft(reply, draft_key: "new_topic", action: "createTopic", **data)
    payload = { "reply" => reply, "action" => action, **data.stringify_keys }
    Draft.set(user, draft_key, DraftSequence.current(user, draft_key), payload.to_json)
    described_class.handle(user, draft_key, payload)
  end

  def enqueued_trigger_data
    Jobs::DiscourseWorkflows::ExecuteWorkflow.jobs.map { |job| job["args"].first["trigger_data"] }
  end

  describe "when a draft is saved", type: :request do
    it "fires the trigger" do
      sign_in(user)

      post "/drafts.json",
           params: {
             draft_key: "new_topic",
             sequence: 0,
             data: { reply: "Magic words", action: "createTopic" }.to_json,
           }

      expect(response.status).to eq(200)
      expect(enqueued_trigger_data.size).to eq(1)
    end
  end

  it "fires once per phrase for each draft" do
    save_draft("Some magic words", title: "Lunch review", workflowsSessionId: "session-1")
    save_draft("Some magic words, and more magic words")
    save_draft("Magic words. food stand")

    expect(enqueued_trigger_data.map { |data| data.dig("composer", "matched_phrases") }).to eq(
      [["Magic words"], ["food stand"]],
    )
    expect(enqueued_trigger_data.first).to include(
      "user" => include("id" => user.id),
      "composer" =>
        include("draft_key" => "new_topic", "session_id" => "session-1", "title" => "Lunch review"),
    )
    expect(Jobs::DiscourseWorkflows::ExecuteWorkflow.jobs.first["args"].first["user_id"]).to eq(
      user.id,
    )
  end

  it "starts over once the draft is cleared" do
    save_draft("Magic words")
    Draft.clear(user, "new_topic", DraftSequence.current(user, "new_topic"))
    save_draft("Magic words")

    expect(enqueued_trigger_data.size).to eq(2)
  end

  it "ignores quoted text" do
    save_draft("[quote=\"sam, post:1, topic:2\"]Magic words[/quote]\n> food stand\nMine")

    expect(enqueued_trigger_data).to be_empty
  end

  it "fires for replies with the topic" do
    save_draft("Magic words", draft_key: "topic_#{topic.id}", action: "reply")

    expect(enqueued_trigger_data.first).to include(
      "topic" => include("id" => topic.id),
      "composer" =>
        include("action" => "reply", "topic_id" => topic.id, "reply_to_post_number" => nil),
    )
  end

  it "reads a reply's target from the draft's post" do
    draft_key = "topic_#{topic.id}"
    target = Fabricate(:post, topic:)

    [target.id, Fabricate(:post).id, [target.id]].each do |post_id|
      save_draft(
        "Magic words",
        draft_key:,
        action: "reply",
        postId: post_id,
        reply_to_post_number: nil,
      )
      Draft.clear(user, draft_key, DraftSequence.current(user, draft_key))
    end

    expect(enqueued_trigger_data.map { |data| data.dig("composer", "reply_to_post_number") }).to eq(
      [target.post_number, nil, nil],
    )
  end

  it "never fires for personal messages or edits" do
    pm = Fabricate(:private_message_topic, user:)

    save_draft("Magic words", draft_key: "new_private_message", action: "privateMessage")
    save_draft("Magic words", draft_key: "topic_#{pm.id}", action: "reply")
    save_draft("Magic words", draft_key: "topic_#{topic.id}", action: "edit", postId: 1)

    expect(enqueued_trigger_data).to be_empty
  end

  it "ignores triggers set to fire on pauses" do
    configuration["fire_on"] = "pause"
    update_workflow_node(workflow, "trigger-1") { |node| node.merge("parameters" => configuration) }
    publish_workflow!(workflow)
    DiscourseWorkflows::WorkflowDependency.clear_cache!

    save_draft("Magic words")

    expect(enqueued_trigger_data).to be_empty
  end

  context "without phrases" do
    let(:configuration) { { "fire_on" => "draft_saved" } }

    it "fires at most once per interval for each draft" do
      save_draft("Hello")
      save_draft("Hello there")
      expect(enqueued_trigger_data.size).to eq(1)

      key = Discourse.redis.keys("discourse_workflows:composer_paused:*").sole
      expect(Discourse.redis.ttl(key)).to be_within(1).of(
        DiscourseWorkflows::ComposerPausedClaims::NO_PHRASES_INTERVAL,
      )

      Discourse.redis.del(key)
      save_draft("Hello there again")
      expect(enqueued_trigger_data.size).to eq(2)
      expect(enqueued_trigger_data.last.dig("composer", "matched_phrases")).to eq([])
    end
  end

  it "is rate limited per user" do
    RateLimiter.enable
    stub_const(DiscourseWorkflows::ComposerPausedClaims, "RATE_LIMIT", 1) do
      save_draft("Magic words", draft_key: "new_topic_1")
      save_draft("Magic words", draft_key: "new_topic_2")
    end

    expect(enqueued_trigger_data.size).to eq(1)
  end

  it "doesn't queue a scan while the user is rate limited" do
    RateLimiter.enable
    stub_const(DiscourseWorkflows::ComposerPausedClaims, "RATE_LIMIT", 1) do
      save_draft("Magic words", draft_key: "new_topic_1")
      allow(Scheduler::Defer).to receive(:later)

      save_draft("Magic words", draft_key: "new_topic_2")
    end

    expect(Scheduler::Defer).not_to have_received(:later)
  end

  context "when scans run in the background" do
    let(:scans) { [] }

    def stub_scans(&handler)
      allow(Scheduler::Defer).to receive(
        :later,
      ).and_wrap_original do |original, desc, *args, **kwargs, &block|
        if desc == "discourse_workflows_composer_paused"
          handler.call(block)
        else
          original.call(desc, *args, **kwargs, &block)
        end
      end
    end

    before { stub_scans { |scan| scans << scan } }
    after { scans.each(&:call) }

    it "queues one scan per draft, which reads the newest autosave" do
      save_draft("Hello")
      save_draft("Magic words")
      save_draft("Hello", draft_key: "topic_#{topic.id}", action: "reply")

      expect(scans.size).to eq(2)
      expect(Scheduler::Defer).to have_received(:later).with(
        "discourse_workflows_composer_paused",
        current_user: user.id,
        force: false,
      ).twice

      scans.shift.call
      expect(enqueued_trigger_data.map { |data| data.dig("composer", "matched_phrases") }).to eq(
        [["Magic words"]],
      )

      save_draft("Magic words, food stand")
      expect(scans.size).to eq(2)
    end

    it "drops the scan when the queue is full" do
      stub_scans { raise WorkQueue::WorkQueueFull }
      save_draft("Magic words")

      stub_scans { |scan| scans << scan }
      save_draft("Magic words")

      expect(scans.size).to eq(1)
    end

    it "lets the next autosave queue a scan when queueing fails" do
      stub_scans { raise ThreadError }
      save_draft("Magic words")

      stub_scans { |scan| scans << scan }
      save_draft("Magic words")

      expect(scans.size).to eq(1)
    end
  end

  it "doesn't match the phrases that already fired" do
    save_draft("Magic words")
    allow(DiscourseWorkflows::Nodes::ComposerPaused::V1).to receive(
      :matched_phrases,
    ).and_call_original

    save_draft("Magic words, food stand")

    expect(DiscourseWorkflows::Nodes::ComposerPaused::V1).to have_received(:matched_phrases).with(
      ["food stand"],
      "Magic words, food stand",
    )
  end

  it "skips users outside the trigger's groups before matching" do
    configuration["group_ids"] = [Fabricate(:group).id]
    update_workflow_node(workflow, "trigger-1") { |node| node.merge("parameters" => configuration) }
    publish_workflow!(workflow)
    DiscourseWorkflows::WorkflowDependency.clear_cache!

    allow(DiscourseWorkflows::Nodes::ComposerPaused::V1).to receive(:matched_phrases)
    save_draft("Magic words")

    expect(DiscourseWorkflows::Nodes::ComposerPaused::V1).not_to have_received(:matched_phrases)
    expect(enqueued_trigger_data).to be_empty
  end

  it "does nothing when workflows are disabled" do
    SiteSetting.enable_discourse_workflows = false

    save_draft("Magic words")

    expect(enqueued_trigger_data).to be_empty
  end
end
