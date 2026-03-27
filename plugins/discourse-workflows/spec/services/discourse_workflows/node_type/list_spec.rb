# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::NodeType::List do
  fab!(:badge) { Fabricate(:badge, name: "Helpful") }

  describe ".call" do
    subject(:result) { described_class.call }

    before do
      SiteSetting.discourse_workflows_enabled = true
      DiscourseWorkflows::Registry.reset!
      DiscourseWorkflows::Registry.register_trigger(DiscourseWorkflows::Triggers::TopicClosed::V1)
      DiscourseWorkflows::Registry.register_action(DiscourseWorkflows::Actions::AppendTags::V1)
      DiscourseWorkflows::Registry.register_action(DiscourseWorkflows::Actions::Code::V1)
      DiscourseWorkflows::Registry.register_action(DiscourseWorkflows::Actions::CreatePost::V1)
      DiscourseWorkflows::Registry.register_action(DiscourseWorkflows::Actions::CreateTopic::V1)
      DiscourseWorkflows::Registry.register_action(DiscourseWorkflows::Actions::DataTable::V1)
      DiscourseWorkflows::Registry.register_action(DiscourseWorkflows::Actions::AwardBadge::V1)
      DiscourseWorkflows::Registry.register_action(DiscourseWorkflows::Actions::SetFields::V1)
      DiscourseWorkflows::Registry.register_condition(
        DiscourseWorkflows::Conditions::IfCondition::V1,
      )
      DiscourseWorkflows::Registry.register_trigger(DiscourseWorkflows::Triggers::Webhook::V1)
      DiscourseWorkflows::Registry.register_trigger(DiscourseWorkflows::Triggers::Manual::V1)
      DiscourseWorkflows::Registry.register_trigger(DiscourseWorkflows::Triggers::Schedule::V1)
    end

    after { DiscourseWorkflows::Registry.reset! }

    context "when everything's ok" do
      it { is_expected.to run_successfully }

      it "returns all registered node types" do
        identifiers = result[:node_types].map { |nt| nt[:identifier] }
        expect(identifiers).to include(
          "trigger:topic_closed",
          "action:append_tags",
          "action:create_post",
          "action:create_topic",
          "condition:if",
        )
      end

      it "includes expected schema fields for each node type" do
        node_type = result[:node_types].find { |nt| nt[:identifier] == "action:create_post" }
        expect(node_type).to include(:id, :identifier, :category, :configuration_schema)
        expect(node_type[:category]).to eq("action")
        expect(node_type[:configuration_schema].keys).to contain_exactly(
          :topic_id,
          :raw,
          :reply_to_post_number,
          :user_id,
        )
      end

      it "returns UI hints for schema-driven configurators" do
        node_type = result[:node_types].find { |nt| nt[:identifier] == "action:create_post" }

        expect(node_type.dig(:configuration_schema, :raw, :ui)).to eq(control: :textarea, rows: 8)
      end

      it "includes specialized property-engine controls in node schemas" do
        award_badge = result[:node_types].find { |nt| nt[:identifier] == "action:award_badge" }
        code = result[:node_types].find { |nt| nt[:identifier] == "action:code" }
        data_table = result[:node_types].find { |nt| nt[:identifier] == "action:data_table" }
        condition = result[:node_types].find { |nt| nt[:identifier] == "condition:if" }
        webhook = result[:node_types].find { |nt| nt[:identifier] == "trigger:webhook" }

        expect(award_badge.dig(:configuration_schema, :badge_id, :ui, :control)).to eq(:combo_box)
        expect(code.dig(:configuration_schema, :code, :ui, :control)).to eq(:code)
        expect(data_table.dig(:configuration_schema, :columns, :ui, :control)).to eq(
          :data_table_columns,
        )
        expect(condition.dig(:configuration_schema, :conditions, :ui, :control)).to eq(
          :condition_builder,
        )
        expect(webhook.dig(:configuration_schema, :url_preview, :ui, :control)).to eq(:url_preview)
      end

      it "includes metadata for badge chooser options" do
        award_badge = result[:node_types].find { |nt| nt[:identifier] == "action:award_badge" }

        expect(award_badge[:metadata][:badges]).to include({ id: badge.id, name: badge.name })
      end

      it "includes branching for condition nodes" do
        condition = result[:node_types].find { |nt| nt[:identifier] == "condition:if" }
        expect(condition[:branching]).to eq(true)
      end

      it "includes manually_triggerable for triggers that support it" do
        manual = result[:node_types].find { |nt| nt[:identifier] == "trigger:manual" }
        schedule = result[:node_types].find { |nt| nt[:identifier] == "trigger:schedule" }
        topic_closed = result[:node_types].find { |nt| nt[:identifier] == "trigger:topic_closed" }

        expect(manual[:manually_triggerable]).to eq(true)
        expect(schedule[:manually_triggerable]).to eq(true)
        expect(topic_closed[:manually_triggerable]).to eq(false)
      end
    end
  end
end
