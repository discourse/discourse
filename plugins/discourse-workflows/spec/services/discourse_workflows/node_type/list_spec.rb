# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::NodeType::List do
  describe ".call" do
    subject(:result) { described_class.call(**dependencies) }

    fab!(:admin)

    let(:dependencies) { { guardian: admin.guardian } }

    context "when user cannot manage workflows" do
      fab!(:user)

      let(:dependencies) { { guardian: user.guardian } }

      it { is_expected.to fail_a_policy(:can_manage_workflows) }
    end

    context "when everything's ok" do
      fab!(:badge) { Fabricate(:badge, name: "Helpful") }
      fab!(:membership_group) { Fabricate(:group, name: "workflow_helpers") }

      it { is_expected.to run_successfully }

      it "returns all registered node types" do
        identifiers = result[:node_types].map { |nt| nt[:identifier] }
        expect(identifiers).to include(
          "trigger:topic_closed",
          "action:topic_tags",
          "action:post",
          "action:topic",
          "condition:if",
        )
        expect(identifiers).not_to include("action:create_post")
      end

      it "includes expected schema fields for each node type" do
        node_type = result[:node_types].find { |nt| nt[:identifier] == "action:post" }
        expect(node_type).to include(
          :displayName,
          :name,
          :version,
          :defaults,
          :inputs,
          :outputs,
          :properties,
          :credentials,
          :webhooks,
        )
        expect(node_type[:name]).to eq("action:post")
        expect(node_type[:kind]).to eq("action")
        expect(node_type[:properties].keys).to include(
          :operation,
          :raw,
          :topic_id,
          :post_id,
          :reply_to_post_number,
          :whisper,
          :author_username,
          :editor_username,
          :include_raw,
          :include_cooked,
          :body_character_limit,
          :query,
        )
        expect(node_type.dig(:properties, :operation, :default)).to eq("create")
        expect(node_type.dig(:properties, :limit)).to include(default: 30, min: 1, max: 800)
        expect(node_type[:operations].map { |operation| operation[:value] }).to eq(
          %w[create edit get list],
        )
      end

      it "returns UI hints for schema-driven configurators" do
        node_type = result[:node_types].find { |nt| nt[:identifier] == "action:post" }

        expect(node_type.dig(:properties, :raw, :ui)).to eq(control: :textarea)
      end

      it "includes specialized property-engine controls in node schemas" do
        award_badge = result[:node_types].find { |nt| nt[:identifier] == "action:badge" }
        code = result[:node_types].find { |nt| nt[:identifier] == "action:code" }
        data_table = result[:node_types].find { |nt| nt[:identifier] == "action:data_table" }
        condition = result[:node_types].find { |nt| nt[:identifier] == "condition:if" }
        webhook = result[:node_types].find { |nt| nt[:identifier] == "trigger:webhook" }

        expect(award_badge.dig(:properties, :badge_id, :ui, :control)).to eq(:combo_box)
        expect(code.dig(:properties, :code, :ui, :control)).to eq(:code)
        expect(data_table.dig(:properties, :columns, :ui, :control)).to eq(:data_table_columns)
        expect(data_table.dig(:properties, :sort_column, :ui, :control)).to eq(
          :data_table_column_select,
        )
        expect(condition.dig(:properties, :conditions, :ui, :control)).to eq(:condition_builder)
        expect(webhook.dig(:properties, :url_preview, :ui, :control)).to eq(:url_preview)
      end

      it "sideloads options metadata for dynamic combo box fields" do
        award_badge = result[:node_types].find { |nt| nt[:identifier] == "action:badge" }

        expect(award_badge.dig(:properties, :badge_id, :type_options)).to include(
          load_options_method: "badges",
        )
        expect(award_badge.dig(:metadata, "badges")).to include(id: badge.id, name: badge.name)
      end

      it "serializes the required group selector for group membership triggers", :aggregate_failures do
        %w[trigger:user_added_to_group trigger:user_removed_from_group].each do |identifier|
          trigger = result[:node_types].find { |node_type| node_type[:identifier] == identifier }

          expect(trigger.dig(:properties, :group_id)).to include(
            type: :integer,
            required: true,
            no_data_expression: true,
            ui: {
              control: :group_select,
            },
          )
          expect(trigger.dig(:metadata, "groups")).to include(
            id: membership_group.id,
            name: membership_group.name,
          )
        end
      end

      it "includes branching for condition nodes" do
        condition = result[:node_types].find { |nt| nt[:identifier] == "condition:if" }
        expect(condition[:branching]).to be(true)
      end

      it "serializes ui palette group for action nodes" do
        post = result[:node_types].find { |nt| nt[:identifier] == "action:post" }
        form = result[:node_types].find { |nt| nt[:identifier] == "action:form" }

        expect(post.dig(:ui, :palette_group, :id)).to eq("discourse_actions")
        expect(form.dig(:ui, :palette_group, :id)).to eq("human_review")
      end

      it "does not serialize internal waiting webhook handlers" do
        form = result[:node_types].find { |nt| nt[:identifier] == "action:form" }

        expect(form[:webhooks]).to include(
          a_hash_including(name: "setup", restart_webhook: true, node_type: "form"),
          a_hash_including(name: "default", restart_webhook: true, node_type: "form"),
          a_hash_including(name: "status", restart_webhook: true, node_type: "form"),
        )
        expect(form[:webhooks]).to all(exclude(:handler))
        expect(form.dig(:description, :webhooks)).to all(exclude(:handler))
      end

      it "serializes ui and operations for data_table node" do
        data_table = result[:node_types].find { |nt| nt[:identifier] == "action:data_table" }

        expect(data_table[:ui]).to include(
          icon: "table",
          color: "violet",
          i18n_prefix: "discourse_workflows",
          i18n_scope: "data_table_node",
          palette_group: a_hash_including(id: "data"),
        )
        expect(data_table[:operations]).to include(
          value: "insert",
          label_key: "discourse_workflows.data_table_node.operations.insert",
        )
      end

      it "serializes capabilities and ports for condition node" do
        condition = result[:node_types].find { |nt| nt[:identifier] == "condition:if" }

        expect(condition[:capabilities]).to include(
          branching: true,
          manually_triggerable: false,
          result_mode: "ports",
        )
        expect(condition[:ports]).to eq(
          [
            {
              key: "true",
              type: "main",
              index: 0,
              primary: true,
              label_key: "discourse_workflows.branch.true",
            },
            {
              key: "false",
              type: "main",
              index: 1,
              primary: false,
              label_key: "discourse_workflows.branch.false",
            },
          ],
        )
      end

      it "does not serialize hidden loop node" do
        loop_node = result[:node_types].find { |nt| nt[:identifier] == "flow:loop_over_items" }

        expect(loop_node).to be_nil
      end

      it "serializes ui palette group for trigger nodes" do
        topic_closed = result[:node_types].find { |nt| nt[:identifier] == "trigger:topic_closed" }

        expect(topic_closed.dig(:ui, :palette_group, :id)).to eq("discourse_triggers")
      end

      it "includes manually_triggerable for triggers that support it" do
        manual = result[:node_types].find { |nt| nt[:identifier] == "trigger:manual" }
        schedule = result[:node_types].find { |nt| nt[:identifier] == "trigger:schedule" }
        form = result[:node_types].find { |nt| nt[:identifier] == "trigger:form" }
        error = result[:node_types].find { |nt| nt[:identifier] == "trigger:error" }
        topic_closed = result[:node_types].find { |nt| nt[:identifier] == "trigger:topic_closed" }

        expect(manual[:manually_triggerable]).to be(true)
        expect(schedule[:manually_triggerable]).to be(true)
        expect(form[:manually_triggerable]).to be(true)
        expect(error[:manually_triggerable]).to be(false)
        expect(topic_closed[:manually_triggerable]).to be(false)
      end

      it "includes credential_types in the result" do
        expect(result[:credential_types]).to include(
          a_hash_including(
            identifier: "basic_auth",
            display_name: "Basic Auth",
            property_schema: DiscourseWorkflows::CredentialTypes::BasicAuth.property_schema,
          ),
        )
      end

      it "exposes first-class credential slots on credential-consuming node types" do
        http_request = result[:node_types].find { |nt| nt[:identifier] == "action:http_request" }

        expect(http_request[:credentials]).to contain_exactly(
          a_hash_including(
            name: "auth",
            credential_types: %w[basic_auth bearer_token header_auth],
            required: false,
            display_options: {
              show: {
                authentication: %w[basic_auth bearer_token header_auth],
              },
            },
          ),
        )
        expect(http_request[:properties]).not_to have_key(:credential_id)
      end
    end
  end

  describe "#fetch_node_types" do
    fab!(:admin)

    it "includes unavailable node types with available: false" do
      reason_key = "discourse_workflows.node_unavailable.test_reason"
      unavailable_class =
        Class.new(DiscourseWorkflows::NodeType) do
          description(
            name: "action:unavailable_palette_test",
            available: false,
            unavailable_reason_key: -> { reason_key },
          )
        end

      DiscoursePluginRegistry.register_discourse_workflows_node(
        unavailable_class,
        Plugin::Instance.new,
      )
      DiscourseWorkflows::Registry.reset_indexes!

      result = described_class.call(guardian: admin.guardian)
      unavailable =
        result[:node_types].find { |nt| nt[:identifier] == "action:unavailable_palette_test" }

      expect(unavailable).to be_present
      expect(unavailable[:available]).to eq(false)
      expect(unavailable[:unavailable_reason_key]).to eq(reason_key)
    ensure
      DiscoursePluginRegistry.discourse_workflows_nodes.delete(unavailable_class)
      DiscourseWorkflows::Registry.reset_indexes!
    end

    it "serializes full descriptions for each registered node version" do
      v1 =
        Class.new(DiscourseWorkflows::NodeType) do
          description(
            name: "action:versioned_palette_test",
            version: "1.0",
            properties: {
              old_field: {
                type: :string,
              },
            },
            outputs: [{ key: "old", primary: true }],
          )
        end
      v2 =
        Class.new(DiscourseWorkflows::NodeType) do
          description(
            name: "action:versioned_palette_test",
            version: "2.0",
            properties: {
              new_field: {
                type: :string,
              },
            },
            outputs: [{ key: "new", primary: true }],
          )
        end

      DiscoursePluginRegistry.register_discourse_workflows_node(v1, Plugin::Instance.new)
      DiscoursePluginRegistry.register_discourse_workflows_node(v2, Plugin::Instance.new)
      DiscourseWorkflows::Registry.reset_indexes!

      result = described_class.call(guardian: admin.guardian)
      node_type =
        result[:node_types].find { |nt| nt[:identifier] == "action:versioned_palette_test" }

      expect(node_type.dig(:latest, :version)).to eq("2.0")
      expect(node_type[:properties]).to have_key(:new_field)
      expect(node_type.dig(:versions, "1.0", :properties)).to have_key(:old_field)
      expect(node_type.dig(:versions, "1.0", :outputs)).to contain_exactly(include(key: "old"))
      expect(node_type.dig(:versions, "2.0", :properties)).to have_key(:new_field)
      expect(node_type).not_to have_key(:latest_version)
      expect(node_type).not_to have_key(:available_versions)
      expect(node_type).not_to have_key(:property_versions)
      expect(node_type).not_to have_key(:property_schema_versions)
      expect(node_type[:latest]).not_to have_key(:property_schema)
    ensure
      DiscoursePluginRegistry._raw_discourse_workflows_nodes.reject! do |entry|
        [v1, v2].include?(entry[:value])
      end
      DiscourseWorkflows::Registry.reset_indexes!
    end
  end
end
