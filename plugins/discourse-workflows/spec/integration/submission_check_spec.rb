# frozen_string_literal: true

RSpec.describe "Before-submission workflows" do
  fab!(:admin)
  fab!(:author) { Fabricate(:user, trust_level: 0, refresh_auto_groups: true) }
  fab!(:owner) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:category)
  fab!(:topic) { Fabricate(:topic_with_op, category: category, user: owner) }

  let(:message) { "New members can reply to their own topics until trust level 1." }

  def check_graph(
    condition: "={{ $json.submission.is_reply && !$json.user.staff && $json.user.trust_level === 0 && $json.topic.user_id !== $json.user.id }}"
  )
    build_workflow_graph do |builder|
      builder.node "trigger",
                   "trigger:before_post_submission",
                   configuration: {
                     "category_ids" => [category.id],
                   }
      builder.node "if",
                   "condition:if",
                   configuration: {
                     "conditions" => [
                       {
                         "operator" => {
                           "type" => "boolean",
                           "operation" => "true",
                         },
                         "leftValue" => condition,
                         "rightValue" => "",
                       },
                     ],
                   }
      builder.node "reject", "action:reject_submission", configuration: { "message" => message }
      builder.connect "trigger", "if"
      builder.connect "if", "reject", output: "true"
    end
  end

  def publish_check(graph = check_graph)
    Fabricate(:discourse_workflows_workflow, created_by: admin, published: true, **graph)
  end

  it "rejects other people's replies before persistence, while allowing own topics, staff, TL1 and new topics" do
    workflow = publish_check
    rejected = PostCreator.new(author, topic_id: topic.id, raw: "A reply that should be rejected")

    expect(rejected.create).not_to be_persisted
    expect(rejected.errors.full_messages.join).to include(message)
    expect(Post.where(raw: "A reply that should be rejected")).not_to exist

    own_topic = Fabricate(:topic_with_op, category: category, user: author)
    expect(
      PostCreator.create!(author, topic_id: own_topic.id, raw: "A reply in my own topic"),
    ).to be_persisted
    expect(
      PostCreator.create!(owner, topic_id: topic.id, raw: "A reply at trust level 1"),
    ).to be_persisted
    expect(PostCreator.create!(admin, topic_id: topic.id, raw: "A staff reply")).to be_persisted
    expect(
      PostCreator.create!(
        author,
        category: category.id,
        title: "A first topic about cooking",
        raw: "A new topic body with plenty of words",
      ),
    ).to be_persisted
    expect(workflow.executions).to be_empty
  end

  it "blocks queued replies and queued topics before reviewables are created" do
    publish_check
    SiteSetting.approve_post_count = 100
    reply = NewPostManager.new(author, topic_id: topic.id, raw: "A queued reply").perform
    expect(reply.success?).to eq(false)
    expect(reply.errors.full_messages.join).to include(message)
    expect(ReviewableQueuedPost.where(target_created_by: author)).not_to exist

    topic_graph = check_graph(condition: "={{ $json.submission.kind === 'topic' }}")
    publish_check(topic_graph)
    topic_result =
      NewPostManager.new(
        author,
        category: category.id,
        title: "A queued topic title",
        raw: "A queued topic body",
      ).perform
    expect(topic_result.success?).to eq(false)
    expect(topic_result.errors.full_messages.join).to include(message)
    expect(ReviewableQueuedPost.where(target_created_by: author)).not_to exist
  end

  it "uses only active published versions and any applicable check may veto" do
    workflow = publish_check(check_graph(condition: "={{ false }}"))
    publish_check
    draft = check_graph(condition: "={{ true }}")
    workflow.update!(**draft)
    result = PostCreator.new(author, topic_id: topic.id, raw: "A checked reply")
    expect(result.create).not_to be_persisted
    expect(result.errors.full_messages.join).to include(message)
    DiscourseWorkflows::WorkflowDependencyIndexer.call(workflow, version: workflow.active_version)
    workflow.update!(active_version_id: nil)
  end

  it "ignores live error-workflow metadata and accepts an informational timezone on the published version" do
    workflow =
      Fabricate(
        :discourse_workflows_workflow,
        created_by: admin,
        published: true,
        settings: {
          "timezone" => "UTC",
        },
        **check_graph,
      )
    expect { workflow.publish! }.not_to raise_error
    workflow.update_columns(
      error_workflow_id: Fabricate(:discourse_workflows_workflow, created_by: admin).id,
    )

    creator =
      PostCreator.new(author, topic_id: topic.id, raw: "A reply that should still be checked")
    expect(creator.create).not_to be_persisted
    expect(creator.errors.full_messages.join).to include(message)
    expect(creator.errors.full_messages.join).not_to include(
      I18n.t("discourse_workflows.errors.submission_check.unavailable"),
    )
  end

  it "runs the shipped template without rejecting new topics or own-topic replies" do
    template =
      JSON.parse(
        File.read(File.join(DiscourseWorkflows::TEMPLATES_PATH, "open-topics-tl1-replies.json")),
      )
    template["nodes"].first["parameters"]["category_ids"] = [category.id]
    Fabricate(
      :discourse_workflows_workflow,
      created_by: admin,
      published: true,
      nodes: template["nodes"],
      connections: template["connections"],
    )

    expect(
      PostCreator.create!(
        author,
        category: category.id,
        title: "A topic that new members may start",
        raw: "A topic body for testing the template",
      ),
    ).to be_persisted
    own_topic = Fabricate(:topic_with_op, category: category, user: author)
    expect(
      PostCreator.create!(author, topic_id: own_topic.id, raw: "Replying to a topic I started"),
    ).to be_persisted
    blocked = PostCreator.new(author, topic_id: topic.id, raw: "Replying to somebody else's topic")
    expect(blocked.create).not_to be_persisted
    expect(blocked.errors.full_messages.join).to include("As a new member, you can start a topic")
  end

  it "queues allowed new topics and replies to one's own topic" do
    publish_check
    SiteSetting.approve_post_count = 100

    topic_result =
      NewPostManager.new(
        author,
        category: category.id,
        title: "A new member's topic",
        raw: "A new member starts a topic",
      ).perform
    expect(topic_result.success?).to eq(true)
    expect(topic_result.action).to eq(:enqueued)

    own_topic = Fabricate(:topic_with_op, category: category, user: author)
    reply_result =
      NewPostManager.new(
        author,
        topic_id: own_topic.id,
        raw: "A queued reply to my own topic",
      ).perform
    expect(reply_result.success?).to eq(true)
    expect(reply_result.action).to eq(:enqueued)
  end

  it "skips unpublished and disabled workflows" do
    workflow = publish_check
    workflow.update!(active_version_id: nil)
    expect(
      PostCreator.create!(author, topic_id: topic.id, raw: "An unpublished check cannot block"),
    ).to be_persisted

    workflow.update!(active_version_id: workflow.version_id)
    SiteSetting.enable_discourse_workflows = false
    expect(
      PostCreator.create!(author, topic_id: topic.id, raw: "A disabled plugin cannot block"),
    ).to be_persisted
  end

  it "blocks failed expressions with a generic error without showing the raw draft" do
    publish_check(check_graph(condition: "={{ missingSubmissionProperty.someValue }}"))
    raw = "My private draft with a unique phrase"
    creator = PostCreator.new(author, topic_id: topic.id, raw: raw)
    creator.create
    expect(creator.errors.full_messages.join).to include(
      I18n.t("discourse_workflows.errors.submission_check.unavailable"),
    )
    expect(creator.errors.full_messages.join).not_to include(raw)
  end

  it "checks new topics in the implicit uncategorized category" do
    uncategorized_id = SiteSetting.uncategorized_category_id
    scoped_graph =
      check_graph(condition: "={{ $json.submission.category_id === #{uncategorized_id} }}")
    scoped_graph[:nodes].first["parameters"]["category_ids"] = [uncategorized_id]
    publish_check(scoped_graph)

    creator =
      PostCreator.new(
        admin,
        title: "A new topic without a category",
        raw: "The topic has no category in its options",
      )
    expect(creator.create).not_to be_persisted
    expect(creator.errors.full_messages.join).to include(message)
  end

  it "checks the actual shared draft category rather than the submitted category" do
    SiteSetting.shared_drafts_category = category.id
    publish_check(check_graph(condition: "={{ $json.submission.category_id === #{category.id} }}"))

    creator =
      PostCreator.new(
        admin,
        title: "A shared draft title",
        raw: "The shared draft body",
        shared_draft: true,
      )
    expect(creator.create).not_to be_persisted
    expect(creator.errors.full_messages.join).to include(message)
  end

  it "ignores an invalid published graph outside its selected category and fails closed inside it" do
    workflow = publish_check
    other_category = Fabricate(:category)
    version = workflow.active_version
    version.update_columns(
      connections: {
        "Trigger" => {
          "main" => [[{ "node" => "Missing", "type" => "main", "index" => 0 }]],
        },
      },
    )

    outside =
      PostCreator.new(
        author,
        category: other_category.id,
        title: "An ordinary topic elsewhere",
        raw: "Ordinary topic content",
      )
    expect(outside.create).to be_persisted

    inside = PostCreator.new(author, topic_id: topic.id, raw: "A new reply inside the category")
    expect(inside.create).not_to be_persisted
    expect(inside.errors.full_messages.join).to include(
      I18n.t("discourse_workflows.errors.submission_check.unavailable"),
    )
  end

  it "skips stale cached triggers after their workflows are unpublished or replaced" do
    workflow = publish_check
    expect(
      DiscourseWorkflows::WorkflowDependency.cached_published_triggers(
        DiscourseWorkflows::SubmissionCheck::Graph::TRIGGER,
      ).map(&:workflow_id),
    ).to include(workflow.id)
    workflow.update_columns(active_version_id: nil)
    expect(
      PostCreator.create!(author, topic_id: topic.id, raw: "A reply after unpublishing"),
    ).to be_persisted

    workflow.snapshot!(user: admin)
    workflow.update_columns(active_version_id: workflow.version_id)
    expect(
      PostCreator.create!(
        author,
        topic_id: topic.id,
        raw: "A reply after replacing the published version",
      ),
    ).to be_persisted
  end

  it "permits private messages and trusted skip_validations without executing checks" do
    publish_check(check_graph(condition: "={{ true }}"))
    expect(
      PostCreator.create!(
        author,
        category: category.id,
        title: "An intentionally bypassed topic",
        raw: "A safe topic body",
        skip_validations: true,
      ),
    ).to be_persisted
    pm =
      PostCreator.new(
        admin,
        archetype: Archetype.private_message,
        target_usernames: owner.username,
        title: "An important private message",
        raw: "A private message body",
      )
    expect(pm.create).to be_persisted
  end

  it "saves and publishes the editor's inert direct-setting defaults on configured nodes" do
    graph = check_graph
    graph[:nodes].each do |node|
      node.merge!("notes" => "", "notesInFlow" => false, "alwaysOutputData" => false)
    end
    graph[:nodes].first["parameters"]["category_ids"] = [category.id]
    graph[:nodes].last["parameters"]["message"] = message
    workflow = Fabricate(:discourse_workflows_workflow, created_by: admin)

    expect(
      DiscourseWorkflows::Workflow::Action::PopulateGraph.call(
        workflow: workflow,
        nodes_data: graph[:nodes],
        connections_data: graph[:connections],
      ),
    ).to eq(true)
    expect(workflow.reload.nodes).to all(
      include("notes" => "", "notesInFlow" => false, "alwaysOutputData" => false),
    )
    workflow.snapshot!(user: admin)
    expect { workflow.publish! }.not_to raise_error
    expect(workflow.reload).to be_published
  end

  it "still rejects behavior-changing direct settings" do
    graph = check_graph
    workflow = Fabricate(:discourse_workflows_workflow, created_by: admin)
    [
      { "alwaysOutputData" => true },
      { "notesInFlow" => true },
      { "onError" => "continueRegularOutput" },
      { "continueOnFail" => true },
      { "notes" => "unexpected" },
    ].each do |settings|
      nodes = graph[:nodes].deep_dup
      nodes.first.merge!(settings)
      expect(
        DiscourseWorkflows::Workflow::Action::PopulateGraph.call(
          workflow: workflow,
          nodes_data: nodes,
          connections_data: graph[:connections],
        ),
      ).to eq(false)
      expect {
        DiscourseWorkflows::SubmissionCheck::Graph.new(
          nodes: nodes,
          connections: graph[:connections],
        ).validate!
      }.to raise_error(DiscourseWorkflows::SubmissionCheck::Graph::Invalid)
      workflow.errors.clear
    end
  end

  it "saves unfinished drafts node by node but refuses to publish them" do
    workflow = Fabricate(:discourse_workflows_workflow, created_by: admin)
    trigger = check_graph[:nodes].first
    trigger["parameters"]["category_ids"] = []

    expect(
      DiscourseWorkflows::Workflow::Action::PopulateGraph.call(
        workflow: workflow,
        nodes_data: [trigger],
        connections_data: {
        },
      ),
    ).to eq(true)
    expect(workflow.reload.nodes.map { |node| node["type"] }).to eq(
      ["trigger:before_post_submission"],
    )

    workflow.snapshot!(user: admin)
    expect { workflow.publish! }.to raise_error(DiscourseWorkflows::SubmissionCheck::Graph::Invalid)
  end

  it "rejects broken links, unsafe nodes, settings, and messages on save and publish" do
    graph = check_graph
    workflow = Fabricate(:discourse_workflows_workflow, created_by: admin, **graph)
    invalid = graph.deep_dup
    invalid[:connections]["If"]["main"][0][0]["node"] = "Missing node"
    expect(
      DiscourseWorkflows::Workflow::Action::PopulateGraph.call(
        workflow: workflow,
        nodes_data: invalid[:nodes],
        connections_data: invalid[:connections],
      ),
    ).to eq(false)
    expect(workflow.reload.connections).to eq(graph[:connections])
    workflow.errors.clear
    validator =
      DiscourseWorkflows::WorkflowGraphValidator.new(
        workflow: workflow,
        nodes_data: invalid[:nodes],
        connections_data: invalid[:connections],
      )
    expect(validator.valid?).to eq(false)
    expect(workflow.errors.full_messages.join).to include(
      I18n.t("discourse_workflows.errors.invalid_submission_check"),
    )
    workflow.errors.clear
    partial =
      DiscourseWorkflows::WorkflowGraphValidator.new(
        workflow: workflow,
        nodes_data: [graph[:nodes].first],
        connections_data: {
        },
      )
    expect(partial.valid?).to eq(true)

    invalid = graph.deep_dup
    invalid[:nodes][1]["type"] = "action:post"
    expect { DiscourseWorkflows::SubmissionCheck::Graph.new(**invalid).validate! }.to raise_error(
      DiscourseWorkflows::SubmissionCheck::Graph::Invalid,
    )
    invalid = graph.deep_dup
    invalid[:nodes][2]["parameters"]["message"] = "={{ $json.submission.raw }}"
    expect { DiscourseWorkflows::SubmissionCheck::Graph.new(**invalid).validate! }.to raise_error(
      DiscourseWorkflows::SubmissionCheck::Graph::Invalid,
    )
    expect {
      DiscourseWorkflows::SubmissionCheck::Graph.new(
        **graph,
        settings: {
          "saveExecutionProgress" => true,
        },
      ).validate!
    }.to raise_error(DiscourseWorkflows::SubmissionCheck::Graph::Invalid)

    workflow.snapshot!(user: admin)
    workflow
      .workflow_versions
      .find_by!(version_id: workflow.version_id)
      .update_columns(nodes: invalid[:nodes])
    expect { workflow.publish! }.to raise_error(DiscourseWorkflows::SubmissionCheck::Graph::Invalid)
  end

  it "evaluates convergent branches once instead of exhausting the graph budget" do
    graph =
      build_workflow_graph do |builder|
        builder.node "trigger",
                     "trigger:before_post_submission",
                     configuration: {
                       "category_ids" => [category.id],
                     }
        (1..9).each do |index|
          builder.node "if-#{index}",
                       "condition:if",
                       configuration: {
                         "conditions" => [
                           {
                             "operator" => {
                               "type" => "boolean",
                               "operation" => "true",
                             },
                             "leftValue" => "={{ true }}",
                             "rightValue" => "",
                           },
                         ],
                       }
        end
        builder.node "reject", "action:reject_submission", configuration: { "message" => message }
        builder.connect "trigger", "if-1"
        (1..9).each do |index|
          target = index == 9 ? "reject" : "if-#{index + 1}"
          2.times { builder.connect "if-#{index}", target }
        end
      end
    validated_graph = DiscourseWorkflows::SubmissionCheck::Graph.new(**graph).validate!

    runner =
      DiscourseWorkflows::SubmissionCheck::Runner.new(
        validated_graph,
        {},
        budget: DiscourseWorkflows::SandboxBudget.new(budget_ms: 500),
      )
    expect(runner.rejection).to eq(message)
  end

  it "cannot run a submission graph in the ordinary executor" do
    workflow = publish_check
    expect { DiscourseWorkflows::Executor.new(workflow, "trigger", {}) }.to raise_error(
      DiscourseWorkflows::SubmissionCheck::Graph::Invalid,
    )
  end
end
