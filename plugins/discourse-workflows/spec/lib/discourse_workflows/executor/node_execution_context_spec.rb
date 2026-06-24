# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Executor::NodeExecutionContext do
  describe "#get_context" do
    it "exposes mutable execution contexts to node implementations" do
      ctx =
        described_class.new(
          input_items: [],
          resolver: nil,
          node_context: {
            "index" => 1,
          },
          flow_context: {
            "shared" => true,
          },
        )

      expect(ctx.get_context).to eq("index" => 1)
      expect(ctx.get_context(:flow)).to eq("shared" => true)
      expect { ctx.get_context(:global) }.to raise_error(
        ArgumentError,
        "Unknown context scope: global. Use :node or :flow",
      )
    end
  end

  describe "#input_context" do
    it "returns the public input context for node execution" do
      ctx =
        described_class.new(
          input_items: [{ "json" => { "username" => "item-user" } }],
          resolver: nil,
          node_context: {
            "no_items_left" => true,
          },
        )

      expect(ctx.input_context).to eq("noItemsLeft" => true)
    end
  end

  describe "#continue_on_fail" do
    it "reads continueOnFail from direct node settings" do
      ctx =
        described_class.new(
          input_items: [],
          resolver: nil,
          node_settings: {
            "continueOnFail" => true,
          },
        )

      expect(ctx.continue_on_fail).to eq(true)
    end

    it "treats onError continue modes as continueOnFail" do
      ctx =
        described_class.new(
          input_items: [],
          resolver: nil,
          node_settings: {
            "onError" => "continueErrorOutput",
          },
        )

      expect(ctx.continue_on_fail).to eq(true)
    end
  end

  describe "node and graph views" do
    let(:snapshot) do
      graph =
        build_workflow_graph do |g|
          g.node "trigger-1", "trigger:manual", name: "Manual"
          g.node "set-1", "action:set_fields", name: "Prepare"
          g.node "form-1",
                 "action:form",
                 name: "Review",
                 configuration: {
                   "form_fields" => [{ "field_label" => "Reason", "field_type" => "text" }],
                 }
          g.chain "trigger-1", "set-1", "form-1"
        end

      DiscourseWorkflows::WorkflowSnapshot.new(graph.merge(workflow_name: "Runtime workflow"))
    end

    it "exposes the current node as a public view" do
      ctx =
        described_class.new(
          input_items: [],
          resolver: nil,
          node_id: "form-1",
          node_identifier: "action:form",
          workflow_snapshot: snapshot,
        )

      expect(ctx.get_node).to have_attributes(
        id: "form-1",
        name: "Review",
        type: "action:form",
        type_version: 1.0,
      )
      expect(ctx.get_node.parameters).to include(
        "form_fields" => [{ "field_label" => "Reason", "field_type" => "text" }],
      )
      expect(ctx.get_node.to_h).to include("typeVersion" => 1.0)
    end

    it "returns recursive parent and child node views from the workflow snapshot" do
      ctx =
        described_class.new(
          input_items: [],
          resolver: nil,
          node_id: "set-1",
          node_identifier: "action:set_fields",
          workflow_snapshot: snapshot,
        )

      expect(ctx.get_parent_nodes(ctx.get_node.name).map(&:name)).to eq(["Manual"])
      expect(ctx.get_child_nodes(ctx.get_node.name).map(&:name)).to eq(["Review"])
      expect(ctx.get_parent_nodes("Review").map(&:name)).to eq(%w[Manual Prepare])
    end

    it "only includes node parameters when requested" do
      ctx =
        described_class.new(
          input_items: [],
          resolver: nil,
          node_id: "set-1",
          node_identifier: "action:set_fields",
          workflow_snapshot: snapshot,
        )

      child = ctx.get_child_nodes(ctx.get_node.name, include_node_parameters: true).first

      expect(child.parameters).to include(
        "form_fields" => [{ "field_label" => "Reason", "field_type" => "text" }],
      )
    end
  end

  describe "#helpers" do
    it "normalizes runtime-compatible items through execution helpers" do
      ctx = described_class.new(input_items: [], resolver: nil)

      expect(ctx.helpers.normalize_items([{ json: { name: "Ada" }, pairedItem: 0 }])).to eq(
        [{ "json" => { "name" => "Ada" }, "pairedItem" => { "item" => 0 } }],
      )
    end

    it "raises node errors for incompatible item formats" do
      ctx = described_class.new(input_items: [], resolver: nil)

      expect { ctx.helpers.normalize_items([{ json: { id: 1 } }, { binary: {} }]) }.to raise_error(
        DiscourseWorkflows::NodeError,
        "Inconsistent item format: Every returned item must use the same format.",
      )
    end
  end

  describe "#get_workflow_static_data" do
    let(:state) do
      DiscourseWorkflows::Executor::StaticDataState.new(
        global: {
          "tenant" => "acme",
        },
        node: {
          "Existing" => {
            "cursor" => "abc",
          },
        },
      )
    end

    it "returns the node-scoped hash for the current node, creating the slot lazily" do
      ctx =
        described_class.new(
          input_items: [],
          resolver: nil,
          node_name: "Fresh",
          static_data_state: state,
        )

      slot = ctx.get_workflow_static_data(:node)
      expect(slot).to eq({})

      slot["seen"] = 1
      expect(state.node["Fresh"]).to eq("seen" => 1)
      expect(state).to be_dirty
    end

    it "returns the existing node slot when one is already present" do
      ctx =
        described_class.new(
          input_items: [],
          resolver: nil,
          node_name: "Existing",
          static_data_state: state,
        )

      expect(ctx.get_workflow_static_data(:node)).to eq("cursor" => "abc")
    end

    it "returns the global hash for :global" do
      ctx =
        described_class.new(
          input_items: [],
          resolver: nil,
          node_name: "Fresh",
          static_data_state: state,
        )

      expect(ctx.get_workflow_static_data(:global)).to eq("tenant" => "acme")
    end

    it "raises when no static_data_state was provided" do
      ctx = described_class.new(input_items: [], resolver: nil, node_name: "Fresh")

      expect { ctx.get_workflow_static_data(:node) }.to raise_error(/not available/)
    end

    it "raises on node scope without a node_name" do
      ctx = described_class.new(input_items: [], resolver: nil, static_data_state: state)

      expect { ctx.get_workflow_static_data(:node) }.to raise_error(/requires a node name/)
    end

    it "raises on unknown scopes" do
      ctx =
        described_class.new(
          input_items: [],
          resolver: nil,
          node_name: "Fresh",
          static_data_state: state,
        )

      expect { ctx.get_workflow_static_data(:bogus) }.to raise_error(ArgumentError)
    end
  end

  describe "#resume_action_id" do
    it "returns a signed action id for interactive resume nodes" do
      ctx =
        described_class.new(
          input_items: [{ "json" => { "username" => "item-user" } }],
          resolver: nil,
          execution_id: 123,
          resume_token: "resume-token",
        )

      payload =
        DiscourseWorkflows::InteractiveResume.action_payload(ctx.resume_action_id("approve"))

      expect(payload).to include("execution_id" => 123, "action" => "approve")
    end
  end

  describe "#set_metadata" do
    it "merges execution metadata with string keys" do
      ctx = described_class.new(input_items: [], resolver: nil)

      ctx.set_metadata(resumeFormUrl: "/resume")

      expect(ctx.metadata).to eq("resumeFormUrl" => "/resume")
    end
  end

  describe "#get_node_parameter" do
    it "resolves a nested parameter path against the current item" do
      ctx, resolver, sandbox =
        build_parameter_context(
          { "outer" => { "inner" => "={{ $json.value }}" } },
          input_items: [{ "json" => { "value" => "resolved" } }],
        )

      value = ctx.get_node_parameter("outer.inner", 0)

      expect(value).to eq("resolved")
    ensure
      resolver&.dispose
      sandbox&.dispose
    end

    it "returns the default for a missing parameter path" do
      ctx, resolver, sandbox = build_parameter_context({ "outer" => {} })

      value = ctx.get_node_parameter("outer.inner", 0, default: "default-value")

      expect(value).to eq("default-value")
    ensure
      resolver&.dispose
      sandbox&.dispose
    end

    it "evaluates condition-builder parameters even when the root key is absent" do
      ctx, resolver, sandbox =
        build_parameter_context({}, schema: { conditions: { ui: { control: :condition_builder } } })

      value = ctx.get_node_parameter(:conditions, 0)

      expect(value).to eq(true)
    ensure
      resolver&.dispose
      sandbox&.dispose
    end

    it "returns literal values for no_data_expression fields" do
      ctx, resolver, sandbox =
        build_parameter_context(
          { "code" => "={{ $json.value }}" },
          schema: {
            code: {
              type: :string,
              no_data_expression: true,
            },
          },
          input_items: [{ "json" => { "value" => "resolved" } }],
        )

      value = ctx.get_node_parameter("code", 0)

      expect(value).to eq("={{ $json.value }}")
    ensure
      resolver&.dispose
      sandbox&.dispose
    end

    it "returns raw stored values when raw_expressions is requested" do
      ctx, resolver, sandbox =
        build_parameter_context(
          { "message" => "={{ $json.value }}" },
          input_items: [{ "json" => { "value" => "resolved" } }],
        )

      resolved = ctx.get_node_parameter("message", 0)
      raw = ctx.get_node_parameter("message", 0, options: { raw_expressions: true })

      expect(resolved).to eq("resolved")
      expect(raw).to eq("={{ $json.value }}")
    ensure
      resolver&.dispose
      sandbox&.dispose
    end
  end

  describe "#get_credentials" do
    fab!(:admin)
    fab!(:credential) do
      Fabricate(
        :discourse_workflows_credential,
        credential_type: "basic_auth",
        data: {
          "user" => "={{ $json.username }}",
          "password" => "static-password",
        },
      )
    end

    it "resolves credential expressions against the current item" do
      resolver_context = { "$json" => {} }
      sandbox = DiscourseWorkflows::JsSandbox.new(resolver_context)
      resolver = DiscourseWorkflows::ExpressionResolver.new(resolver_context, sandbox: sandbox)
      ctx =
        described_class.new(
          input_items: [{ "json" => { "username" => "item-user" } }],
          parameters: {
            "authentication" => "basic_auth",
          },
          credentials: {
            "auth" => {
              "id" => credential.id,
              "credential_type" => "basic_auth",
            },
          },
          credential_schema: DiscourseWorkflows::Nodes::HttpRequest::V1.credentials,
          resolver: resolver,
        )

      resolved = ctx.get_credentials("auth", 0)

      expect(resolved).to eq("user" => "item-user", "password" => "static-password")
    ensure
      resolver&.dispose
      sandbox&.dispose
    end

    it "allows access when the current workflow node references the credential" do
      workflow = workflow_with_credential_dependency(credential)
      ctx, resolver, sandbox =
        build_credential_context(
          workflow: workflow,
          input_items: [{ "json" => { "username" => "dependency-user" } }],
        )

      resolved = ctx.get_credentials("auth", 0)

      expect(resolved).to eq("user" => "dependency-user", "password" => "static-password")
    ensure
      resolver&.dispose
      sandbox&.dispose
    end

    it "denies access when the current workflow node does not reference the credential" do
      workflow = workflow_with_credential_dependency(credential)
      DiscourseWorkflows::WorkflowDependency.where(workflow_id: workflow.id).delete_all
      ctx, resolver, sandbox = build_credential_context(workflow: workflow)

      expect { ctx.get_credentials("auth") }.to raise_error(Discourse::InvalidAccess)
    ensure
      resolver&.dispose
      sandbox&.dispose
    end

    it "rejects undeclared credential slots" do
      ctx, resolver, sandbox =
        build_credential_context(
          credentials: {
            "other" => {
              "id" => credential.id,
              "credential_type" => "basic_auth",
            },
          },
        )

      expect { ctx.get_credentials("other") }.to raise_error(Discourse::InvalidAccess)
    ensure
      resolver&.dispose
      sandbox&.dispose
    end

    it "raises when the node is not configured to use the requested credential" do
      resolver_context = { "$json" => {} }
      sandbox = DiscourseWorkflows::JsSandbox.new(resolver_context)
      resolver = DiscourseWorkflows::ExpressionResolver.new(resolver_context, sandbox: sandbox)
      ctx =
        described_class.new(
          input_items: [],
          parameters: {
            "authentication" => "basic_auth",
          },
          credentials: {
            "auth" => {
              "id" => credential.id + 1,
              "credential_type" => "basic_auth",
            },
          },
          credential_schema: DiscourseWorkflows::Nodes::HttpRequest::V1.credentials,
          resolver: resolver,
        )

      expect { ctx.get_credentials("auth") }.to raise_error(Discourse::InvalidAccess)
    ensure
      resolver&.dispose
      sandbox&.dispose
    end
  end

  describe "#helpers" do
    fab!(:admin)
    fab!(:data_table, :discourse_workflows_data_table)

    it "returns a Data Table node proxy for the requested data table when config references it" do
      ctx =
        described_class.new(
          input_items: [],
          parameters: {
            "data_table_id" => data_table.id,
          },
          node_identifier: "action:data_table",
          resolver: nil,
        )

      expect(ctx.helpers.get_data_table_proxy(data_table.id)).to be_a(
        DiscourseWorkflows::DataTables::NodeProxy,
      )
    end

    it "allows access when the current workflow node references the data table" do
      workflow = workflow_with_data_table_dependency(data_table)
      ctx = build_data_table_context(workflow: workflow)

      expect(ctx.helpers.get_data_table_proxy(data_table.id)).to be_a(
        DiscourseWorkflows::DataTables::NodeProxy,
      )
    end

    it "returns a Data Table aggregate proxy for allowed nodes" do
      ctx = build_data_table_context

      expect(ctx.helpers.get_data_table_aggregate_proxy).to be_a(
        DiscourseWorkflows::DataTables::AggregateNodeProxy,
      )
    end

    it "denies access when the current workflow node does not reference the data table" do
      workflow = workflow_with_data_table_dependency(data_table)
      DiscourseWorkflows::WorkflowDependency.where(workflow_id: workflow.id).delete_all
      ctx = build_data_table_context(workflow: workflow)

      expect { ctx.helpers.get_data_table_proxy(data_table.id) }.to raise_error(
        Discourse::InvalidAccess,
      )
    end

    it "does not reveal whether an unauthorized data table id exists" do
      ctx = build_data_table_context(configuration: { "data_table_id" => data_table.id + 1 })

      expect { ctx.helpers.get_data_table_proxy(data_table.id) }.to raise_error(
        Discourse::InvalidAccess,
      )
    end

    it "raises when the node is not configured to use the requested data table" do
      ctx =
        described_class.new(
          input_items: [],
          parameters: {
            "data_table_id" => data_table.id + 1,
          },
          node_identifier: "action:data_table",
          resolver: nil,
        )

      expect { ctx.helpers.get_data_table_proxy(data_table.id) }.to raise_error(
        Discourse::InvalidAccess,
      )
    end

    it "does not expose Data Table helpers to other node types" do
      ctx =
        described_class.new(
          input_items: [],
          parameters: {
            "data_table_id" => data_table.id,
          },
          node_identifier: "action:badge",
          resolver: nil,
        )

      expect { ctx.helpers.get_data_table_proxy(data_table.id) }.to raise_error(
        Discourse::InvalidAccess,
      )
    end
  end

  describe "#find_user" do
    fab!(:user)

    it "finds a user by username" do
      ctx = described_class.new(input_items: [], resolver: nil)

      expect(ctx.find_user(username: user.username)).to eq(user)
    end

    it "finds a user by id" do
      ctx = described_class.new(input_items: [], resolver: nil)

      expect(ctx.find_user(id: user.id)).to eq(user)
    end

    it "raises a node error when the username cannot be found" do
      ctx = described_class.new(input_items: [], resolver: nil)

      expect { ctx.find_user(username: "nonexistent_user") }.to raise_error(
        DiscourseWorkflows::NodeError,
        "User 'nonexistent_user' not found",
      )
    end

    it "raises a node error when the id cannot be found" do
      ctx = described_class.new(input_items: [], resolver: nil)

      expect { ctx.find_user(id: -999) }.to raise_error(
        DiscourseWorkflows::NodeError,
        "User with id -999 not found",
      )
    end

    it "requires exactly one lookup key" do
      ctx = described_class.new(input_items: [], resolver: nil)

      expect { ctx.find_user }.to raise_error(
        ArgumentError,
        "Provide exactly one of username or id",
      )
      expect { ctx.find_user(username: user.username, id: user.id) }.to raise_error(
        ArgumentError,
        "Provide exactly one of username or id",
      )
    end
  end

  describe "#actor_from_parameter" do
    fab!(:user)

    it "resolves actor fields through the central actor policy" do
      resolver_context = { "$json" => { "actor" => user.username } }
      sandbox = DiscourseWorkflows::JsSandbox.new(resolver_context)
      resolver = DiscourseWorkflows::ExpressionResolver.new(resolver_context, sandbox: sandbox)
      policy = instance_spy(DiscourseWorkflows::Executor::ActorPolicy)
      allow(DiscourseWorkflows::Executor::ActorPolicy).to receive(:new).and_return(policy)
      ctx =
        described_class.new(
          input_items: [{ "json" => { "actor" => user.username } }],
          parameters: {
            "actor_username" => "={{ $json.actor }}",
          },
          resolver: resolver,
          node_identifier: "action:post",
        )

      expect(ctx.actor_from_parameter("actor_username")).to eq(user)
      expect(policy).to have_received(:ensure_allowed!).with(
        user,
        field: "actor_username",
        item_index: 0,
        source: :expression,
        purpose: "action:post",
      )
    ensure
      resolver&.dispose
      sandbox&.dispose
    end

    it "rejects actors with restricted account states" do
      staged_user = Fabricate(:user, staged: true)
      silenced_user = Fabricate(:user, silenced_till: 1.year.from_now)
      suspended_user = Fabricate(:user, suspended_till: 1.year.from_now)
      inactive_user = Fabricate(:user, active: false)
      ctx = described_class.new(input_items: [], resolver: nil)

      aggregate_failures do
        expect { ctx.actor_from(username: staged_user.username) }.to raise_error(
          Discourse::InvalidAccess,
        )
        expect { ctx.actor_from(username: silenced_user.username) }.to raise_error(
          Discourse::InvalidAccess,
        )
        expect { ctx.actor_from(username: suspended_user.username) }.to raise_error(
          Discourse::InvalidAccess,
        )
        expect { ctx.actor_from(username: inactive_user.username) }.to raise_error(
          Discourse::InvalidAccess,
        )
      end
    end

    it "defaults to the system user when the actor field is not configured" do
      resolver_context = { "$json" => {} }
      sandbox = DiscourseWorkflows::JsSandbox.new(resolver_context)
      resolver = DiscourseWorkflows::ExpressionResolver.new(resolver_context, sandbox: sandbox)
      ctx = described_class.new(input_items: [], parameters: {}, resolver: resolver)

      expect(ctx.actor_from_parameter("actor_username")).to eq(Discourse.system_user)
    ensure
      resolver&.dispose
      sandbox&.dispose
    end

    it "raises when a configured actor field resolves to a blank value" do
      resolver_context = { "$json" => {} }
      sandbox = DiscourseWorkflows::JsSandbox.new(resolver_context)
      resolver = DiscourseWorkflows::ExpressionResolver.new(resolver_context, sandbox: sandbox)
      ctx =
        described_class.new(
          input_items: [],
          parameters: {
            "actor_username" => "",
          },
          resolver: resolver,
        )

      expect { ctx.actor_from_parameter("actor_username") }.to raise_error(
        DiscourseWorkflows::NodeError,
        I18n.t("discourse_workflows.errors.actor.blank", field: "actor_username"),
      )
    ensure
      resolver&.dispose
      sandbox&.dispose
    end

    it "raises when an actor expression resolves to a blank value" do
      resolver_context = { "$json" => { "actor" => "" } }
      sandbox = DiscourseWorkflows::JsSandbox.new(resolver_context)
      resolver = DiscourseWorkflows::ExpressionResolver.new(resolver_context, sandbox: sandbox)
      ctx =
        described_class.new(
          input_items: [{ "json" => { "actor" => "" } }],
          parameters: {
            "actor_username" => "={{ $json.actor }}",
          },
          resolver: resolver,
        )

      expect { ctx.actor_from_parameter("actor_username") }.to raise_error(
        DiscourseWorkflows::NodeError,
        I18n.t("discourse_workflows.errors.actor.blank", field: "actor_username"),
      )
    ensure
      resolver&.dispose
      sandbox&.dispose
    end

    it "resolves the anonymous sentinel to an anonymous guardian actor" do
      resolver_context = { "$json" => {} }
      sandbox = DiscourseWorkflows::JsSandbox.new(resolver_context)
      resolver = DiscourseWorkflows::ExpressionResolver.new(resolver_context, sandbox: sandbox)
      ctx =
        described_class.new(
          input_items: [],
          parameters: {
            "actor_username" => DiscourseWorkflows::AnonymousActor::USERNAME,
          },
          resolver: resolver,
        )

      actor = ctx.actor_from_parameter("actor_username")

      expect(actor).to be_a(DiscourseWorkflows::AnonymousActor)
      expect(actor.guardian.anonymous?).to eq(true)
    ensure
      resolver&.dispose
      sandbox&.dispose
    end
  end

  describe "#create_post" do
    fab!(:admin)
    fab!(:user)
    fab!(:first_post) { Fabricate(:post, user: user, raw: "First post", post_number: 1) }
    fab!(:topic) { first_post.topic }

    it "creates a reply as the provided user" do
      ctx = described_class.new(input_items: [], resolver: nil)

      expect do
        post =
          ctx.create_post(
            user: admin,
            raw: "Workflow reply",
            topic_id: topic.id,
            reply_to_post_number: first_post.post_number,
          )

        expect(post.raw).to eq("Workflow reply")
        expect(post.user_id).to eq(admin.id)
        expect(post.reply_to_post_number).to eq(first_post.post_number)
      end.to change { topic.posts.count }.by(1)
    end

    it "creates a whisper reply as a whisperer" do
      SiteSetting.whispers_allowed_groups = Group::AUTO_GROUPS[:staff].to_s
      ctx = described_class.new(input_items: [], resolver: nil)

      expect do
        post =
          ctx.create_post(user: admin, raw: "Workflow whisper", topic_id: topic.id, whisper: true)

        expect(post.post_type).to eq(Post.types[:whisper])
      end.to change { topic.posts.count }.by(1)
    end

    it "requires the user to create whispers" do
      SiteSetting.whispers_allowed_groups = Group::AUTO_GROUPS[:staff].to_s
      ctx = described_class.new(input_items: [], resolver: nil)

      expect do
        ctx.create_post(user: user, raw: "Unauthorized whisper", topic_id: topic.id, whisper: true)
      end.to raise_error(Discourse::InvalidAccess).and not_change { topic.posts.count }
    end

    it "requires the user to see the topic" do
      group = Fabricate(:group)
      private_category = Fabricate(:private_category, group: group)
      hidden_topic = Fabricate(:topic, category: private_category)
      ctx = described_class.new(input_items: [], resolver: nil)

      expect do
        ctx.create_post(user: user, raw: "Hidden reply", topic_id: hidden_topic.id)
      end.to raise_error(Discourse::InvalidAccess).and not_change { hidden_topic.posts.count }
    end

    it "raises a node error when the topic is closed or archived" do
      topic.update!(closed: true)
      ctx = described_class.new(input_items: [], resolver: nil)

      expect do
        ctx.create_post(user: admin, raw: "Workflow reply", topic_id: topic.id)
      end.to raise_error(
        DiscourseWorkflows::NodeError,
        /Cannot create a post in a closed or archived topic/,
      )
    end
  end

  describe "#edit_post" do
    fab!(:admin)
    fab!(:user)
    fab!(:post) { Fabricate(:post, user: user, raw: "Original post") }

    it "edits a post as the provided user" do
      ctx = described_class.new(input_items: [], resolver: nil)

      edited_post = ctx.edit_post(user: admin, post_id: post.id, raw: "Edited body")

      expect(edited_post).to eq(post)
      expect(post.reload.raw).to eq("Edited body")
    end

    it "requires the user to edit the post" do
      group = Fabricate(:group)
      private_category = Fabricate(:private_category, group: group)
      hidden_post = create_post(user: admin, category: private_category)
      ctx = described_class.new(input_items: [], resolver: nil)

      expect do
        ctx.edit_post(user: user, post_id: hidden_post.id, raw: "Hidden edit")
      end.to raise_error(Discourse::InvalidAccess)

      expect(hidden_post.reload.raw).not_to eq("Hidden edit")
    end
  end

  describe "#serialize_post" do
    fab!(:user)
    fab!(:post) { Fabricate(:post, user: user, raw: "Workflow post body") }

    it "serializes a post for workflow output" do
      ctx = described_class.new(input_items: [], resolver: nil)

      result = ctx.serialize_post(post, guardian: user.guardian, include_cooked: true)

      expect(result).to include(
        id: post.id,
        topic_id: post.topic_id,
        topic_title: post.topic.title,
        post_number: post.post_number,
        username: user.username,
        raw: "Workflow post body",
        cooked: post.cooked,
      )
    end

    it "can omit raw and cooked body fields" do
      ctx = described_class.new(input_items: [], resolver: nil)

      result =
        ctx.serialize_post(post, guardian: user.guardian, include_raw: false, include_cooked: false)

      expect(result).not_to include(:raw, :cooked)
    end
  end

  describe "#serialize_topic" do
    fab!(:user)
    fab!(:topic) { Fabricate(:topic, user: user) }

    it "serializes a topic for workflow output" do
      topic.custom_fields["workflow_key"] = "workflow value"
      topic.custom_fields["other_key"] = "other value"
      topic.save_custom_fields
      ctx = described_class.new(input_items: [], resolver: nil)

      result =
        ctx.serialize_topic(
          topic.reload,
          guardian: user.guardian,
          custom_field_names: ["workflow_key"],
        )

      expect(result).to include(
        id: topic.id,
        title: topic.title,
        category_id: topic.category_id,
        custom_fields: {
          workflow_key: "workflow value",
        },
      )
      expect(result[:custom_fields]).not_to include(:other_key)
    end

    it "omits custom fields by default" do
      topic.custom_fields["workflow_key"] = "workflow value"
      topic.save_custom_fields
      ctx = described_class.new(input_items: [], resolver: nil)

      result = ctx.serialize_topic(topic, guardian: user.guardian)

      expect(result).not_to include(:custom_fields)
    end
  end

  describe "#http_request" do
    it "returns a parsed response object" do
      stub_request(:get, "https://api.example.com/data").to_return(
        status: 200,
        body: { ok: true }.to_json,
        headers: {
          "content-type" => "application/json",
        },
      )

      ctx = described_class.new(input_items: [], resolver: nil)
      response = ctx.http_request(method: "GET", url: "https://api.example.com/data")

      expect(response.status).to eq(200)
      expect(response.headers).to include("content-type" => "application/json")
      expect(response.body).to eq("ok" => true)
    end

    it "does not retry transient GET response statuses by default" do
      stub_request(:get, "https://api.example.com/retry").to_return(
        { status: 503, body: "unavailable" },
        {
          status: 200,
          body: { ok: true }.to_json,
          headers: {
            "content-type" => "application/json",
          },
        },
      )

      ctx = described_class.new(input_items: [], resolver: nil)

      expect {
        ctx.http_request(method: "GET", url: "https://api.example.com/retry")
      }.to raise_error(
        DiscourseWorkflows::NodeError,
        "HTTP GET https://api.example.com/retry failed with status 503",
      )
      expect(WebMock).to have_requested(:get, "https://api.example.com/retry").once
    end

    it "does not retry non-GET transient response statuses by default" do
      stub_request(:post, "https://api.example.com/retry").to_return(
        status: 503,
        body: "unavailable",
      )

      ctx = described_class.new(input_items: [], resolver: nil)

      expect {
        ctx.http_request(method: "POST", url: "https://api.example.com/retry")
      }.to raise_error(
        DiscourseWorkflows::NodeError,
        "HTTP POST https://api.example.com/retry failed with status 503",
      )
      expect(WebMock).to have_requested(:post, "https://api.example.com/retry").once
    end

    it "allows callers to opt non-GET requests into retries" do
      stub_request(:post, "https://api.example.com/retry").to_return(
        { status: 503, body: "unavailable" },
        {
          status: 200,
          body: { ok: true }.to_json,
          headers: {
            "content-type" => "application/json",
          },
        },
      )

      ctx = described_class.new(input_items: [], resolver: nil)
      response =
        ctx.http_request(
          method: "POST",
          url: "https://api.example.com/retry",
          options: {
            max_retries: 1,
          },
        )

      expect(response.status).to eq(200)
      expect(WebMock).to have_requested(:post, "https://api.example.com/retry").twice
    end
  end

  def workflow_with_data_table_dependency(data_table)
    graph =
      build_workflow_graph do |g|
        g.node "dt-1", "action:data_table", configuration: { "data_table_id" => data_table.id }
      end
    Fabricate(:discourse_workflows_workflow, created_by: admin, **graph)
  end

  def build_data_table_context(workflow: nil, configuration: { "data_table_id" => data_table.id })
    described_class.new(
      input_items: [],
      parameters: configuration,
      resolver: nil,
      workflow: workflow,
      node_id: workflow ? "dt-1" : nil,
      node_identifier: "action:data_table",
    )
  end

  def workflow_with_credential_dependency(credential)
    graph =
      build_workflow_graph do |g|
        g.node "http-1",
               "action:http_request",
               parameters: {
                 "authentication" => "basic_auth",
               },
               credentials: {
                 "auth" => {
                   "id" => credential.id,
                   "credential_type" => "basic_auth",
                 },
               }
      end
    Fabricate(:discourse_workflows_workflow, created_by: admin, **graph)
  end

  def build_credential_context(
    workflow: nil,
    configuration: { "authentication" => "basic_auth" },
    credentials: { "auth" => { "id" => credential.id, "credential_type" => "basic_auth" } },
    input_items: []
  )
    resolver_context = { "$json" => {} }
    sandbox = DiscourseWorkflows::JsSandbox.new(resolver_context)
    resolver = DiscourseWorkflows::ExpressionResolver.new(resolver_context, sandbox: sandbox)
    ctx =
      described_class.new(
        input_items: input_items,
        parameters: configuration,
        credentials: credentials,
        credential_schema: DiscourseWorkflows::Nodes::HttpRequest::V1.credentials,
        resolver: resolver,
        workflow: workflow,
        node_id: workflow ? "http-1" : nil,
      )
    [ctx, resolver, sandbox]
  end

  def build_parameter_context(
    parameters = nil,
    schema: {},
    input_items: [{ "json" => {} }],
    **keyword_parameters
  )
    parameters ||= keyword_parameters
    resolver_context = { "$json" => {} }
    sandbox = DiscourseWorkflows::JsSandbox.new(resolver_context)
    resolver = DiscourseWorkflows::ExpressionResolver.new(resolver_context, sandbox: sandbox)
    ctx =
      described_class.new(
        input_items: input_items,
        parameters: parameters,
        property_schema: schema,
        resolver: resolver,
      )
    [ctx, resolver, sandbox]
  end
end
