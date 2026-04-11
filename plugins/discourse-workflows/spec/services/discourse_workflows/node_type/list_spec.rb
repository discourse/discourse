# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::NodeType::List do
  fab!(:badge) { Fabricate(:badge, name: "Helpful") }

  describe ".call" do
    subject(:result) { described_class.call }

    context "when everything's ok" do
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
        expect(node_type).to include(:id, :identifier, :category, :property_schema)
        expect(node_type[:category]).to eq("action")
        expect(node_type[:property_schema].keys).to contain_exactly(
          :topic_id,
          :raw,
          :reply_to_post_number,
          :user_id,
        )
      end

      it "returns UI hints for schema-driven configurators" do
        node_type = result[:node_types].find { |nt| nt[:identifier] == "action:create_post" }

        expect(node_type.dig(:property_schema, :raw, :ui)).to eq(control: :textarea, rows: 8)
      end

      it "includes specialized property-engine controls in node schemas" do
        award_badge = result[:node_types].find { |nt| nt[:identifier] == "action:badge" }
        code = result[:node_types].find { |nt| nt[:identifier] == "action:code" }
        data_table = result[:node_types].find { |nt| nt[:identifier] == "action:data_table" }
        condition = result[:node_types].find { |nt| nt[:identifier] == "condition:if" }
        webhook = result[:node_types].find { |nt| nt[:identifier] == "trigger:webhook" }

        expect(award_badge.dig(:property_schema, :badge_id, :ui, :control)).to eq(:combo_box)
        expect(code.dig(:property_schema, :code, :ui, :control)).to eq(:code)
        expect(data_table.dig(:property_schema, :columns, :ui, :control)).to eq(
          :data_table_columns,
        )
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

      it "serializes canonical ui, capability, port, and operation descriptors" do
        create_post = result[:node_types].find { |nt| nt[:identifier] == "action:create_post" }
        data_table = result[:node_types].find { |nt| nt[:identifier] == "action:data_table" }
        condition = result[:node_types].find { |nt| nt[:identifier] == "condition:if" }
        form = result[:node_types].find { |nt| nt[:identifier] == "action:form" }
        loop = result[:node_types].find { |nt| nt[:identifier] == "flow:loop_over_items" }
        topic_closed = result[:node_types].find { |nt| nt[:identifier] == "trigger:topic_closed" }

        expect(create_post.dig(:ui, :palette_group, :id)).to eq("discourse_actions")
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
        expect(form.dig(:ui, :palette_group, :id)).to eq("human_review")
        expect(loop[:ports].map { |port| port[:key] }).to eq(%w[done loop])
        expect(loop.dig(:ui, :palette_group, :id)).to eq("flow")
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
            property_schema:
              DiscourseWorkflows::CredentialTypes::BasicAuth.property_schema,
          ),
        )
      end
    end
  end
end
