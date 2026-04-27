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

      it { is_expected.to run_successfully }

      it "returns all registered node types" do
        identifiers = result[:node_types].map { |nt| nt[:identifier] }
        expect(identifiers).to include(
          "trigger:topic_closed",
          "action:topic_tags",
          "action:create_post",
          "action:create_topic",
          "condition:if",
        )
      end

      it "includes expected schema fields for each node type" do
        node_type = result[:node_types].find { |nt| nt[:identifier] == "action:create_post" }
        expect(node_type).to include(:identifier, :kind, :property_schema)
        expect(node_type[:kind]).to eq("action")
        expect(node_type[:property_schema].keys).to contain_exactly(
          :topic_id,
          :raw,
          :reply_to_post_number,
          :user_id,
        )
      end

      it "returns UI hints for schema-driven configurators" do
        node_type = result[:node_types].find { |nt| nt[:identifier] == "action:create_post" }

        expect(node_type.dig(:property_schema, :raw, :ui)).to eq(control: :textarea)
      end

      it "includes specialized property-engine controls in node schemas" do
        award_badge = result[:node_types].find { |nt| nt[:identifier] == "action:badge" }
        code = result[:node_types].find { |nt| nt[:identifier] == "action:code" }
        data_table = result[:node_types].find { |nt| nt[:identifier] == "action:data_table" }
        condition = result[:node_types].find { |nt| nt[:identifier] == "condition:if" }
        webhook = result[:node_types].find { |nt| nt[:identifier] == "trigger:webhook" }

        expect(award_badge.dig(:property_schema, :badge_id, :ui, :control)).to eq(:combo_box)
        expect(code.dig(:property_schema, :code, :ui, :control)).to eq(:code)
        expect(data_table.dig(:property_schema, :columns, :ui, :control)).to eq(:data_table_columns)
        expect(data_table.dig(:property_schema, :sort_column, :ui, :control)).to eq(
          :data_table_column_select,
        )
        expect(condition.dig(:property_schema, :conditions, :ui, :control)).to eq(
          :condition_builder,
        )
        expect(webhook.dig(:property_schema, :url_preview, :ui, :control)).to eq(:url_preview)
      end

      it "includes metadata for badge chooser options" do
        award_badge = result[:node_types].find { |nt| nt[:identifier] == "action:badge" }

        expect(award_badge[:metadata][:badges]).to include({ id: badge.id, name: badge.name })
      end

      it "includes branching for condition nodes" do
        condition = result[:node_types].find { |nt| nt[:identifier] == "condition:if" }
        expect(condition[:branching]).to be(true)
      end

      it "serializes ui palette group for action nodes" do
        create_post = result[:node_types].find { |nt| nt[:identifier] == "action:create_post" }
        form = result[:node_types].find { |nt| nt[:identifier] == "action:form" }

        expect(create_post.dig(:ui, :palette_group, :id)).to eq("discourse_actions")
        expect(form.dig(:ui, :palette_group, :id)).to eq("human_review")
      end

      it "serializes ui and operations for data_table node" do
        data_table = result[:node_types].find { |nt| nt[:identifier] == "action:data_table" }

        expect(data_table[:ui]).to include(
          icon: "table",
          color: "violet",
          property_i18n_prefix: "discourse_workflows",
          property_i18n_scope: "data_table_node",
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
            { key: "true", primary: true, label_key: "discourse_workflows.branch.true" },
            { key: "false", primary: false, label_key: "discourse_workflows.branch.false" },
          ],
        )
      end

      it "serializes ports and ui palette group for loop node" do
        loop_node = result[:node_types].find { |nt| nt[:identifier] == "flow:loop_over_items" }

        expect(loop_node[:ports].map { |port| port[:key] }).to eq(%w[done loop])
        expect(loop_node.dig(:ui, :palette_group, :id)).to eq("flow")
      end

      it "serializes ui palette group for trigger nodes" do
        topic_closed = result[:node_types].find { |nt| nt[:identifier] == "trigger:topic_closed" }

        expect(topic_closed.dig(:ui, :palette_group, :id)).to eq("discourse_triggers")
      end

      it "includes manually_triggerable for triggers that support it" do
        manual = result[:node_types].find { |nt| nt[:identifier] == "trigger:manual" }
        schedule = result[:node_types].find { |nt| nt[:identifier] == "trigger:schedule" }
        form = result[:node_types].find { |nt| nt[:identifier] == "trigger:form" }
        topic_closed = result[:node_types].find { |nt| nt[:identifier] == "trigger:topic_closed" }

        expect(manual[:manually_triggerable]).to be(true)
        expect(schedule[:manually_triggerable]).to be(true)
        expect(form[:manually_triggerable]).to be(true)
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
    end
  end

  describe "#fetch_node_types" do
    fab!(:admin)

    it "includes unavailable node types with available: false" do
      unavailable_class =
        Class.new(DiscourseWorkflows::NodeType) do
          def self.identifier
            "action:unavailable_palette_test"
          end

          def self.name
            "DiscourseWorkflows::Nodes::UnavailablePaletteTest"
          end

          def self.available?
            false
          end

          def self.unavailable_reason_key
            "discourse_workflows.node_unavailable.test_reason"
          end
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
      expect(unavailable[:unavailable_reason_key]).to eq(
        "discourse_workflows.node_unavailable.test_reason",
      )
    ensure
      DiscoursePluginRegistry.discourse_workflows_nodes.delete(unavailable_class)
      DiscourseWorkflows::Registry.reset_indexes!
    end
  end
end
