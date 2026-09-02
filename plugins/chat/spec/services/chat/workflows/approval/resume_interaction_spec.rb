# frozen_string_literal: true

RSpec.describe Chat::Workflows::Approval::ResumeInteraction do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:interaction_id) }
  end

  describe ".call" do
    subject(:result) { described_class.call(params:) }

    fab!(:workflow_owner, :user)
    fab!(:clicking_user, :user)
    fab!(:channel, :chat_channel)

    let(:node_version) { "2.0" }
    let(:button_rows) do
      [
        { "label" => "Approve", "value" => "approve" },
        { "label" => "Needs changes", "value" => "needs:changes" },
      ]
    end
    let(:approval_configuration) do
      {
        "message" => "Approve?",
        "buttons" => {
          "values" => button_rows,
        },
        "channel_id" => channel.id.to_s,
      }
    end
    let(:workflow) do
      graph =
        build_workflow_graph do |builder|
          builder.node "trigger-1", "trigger:manual", name: "Manual"
          builder.node(
            "wait-1",
            "action:chat_approval",
            name: "Wait",
            configuration: approval_configuration,
          )
          builder.node("after-1", "action:code", name: "After", configuration: { "code" => <<~JS })
                var items = $input.all();
                items.forEach(function(item) {
                  item.json.current_user_id = $current_user.id || null;
                });
                return items;
              JS

          builder.chain "trigger-1", "wait-1", "after-1"
        end
      if node_version
        graph[:nodes].find { |node| node["id"] == "wait-1" }["typeVersion"] = node_version
      end

      Fabricate(:discourse_workflows_workflow, created_by: workflow_owner, **graph).tap do |record|
        publish_workflow!(record)
      end
    end
    let(:execution) { DiscourseWorkflows::Executor.new(workflow, "trigger-1", {}).run }
    let(:message) do
      execution
      Chat::Message.where(chat_channel_id: channel.id).last
    end
    let(:button_index) { 0 }
    let(:button) { message.blocks.first["elements"][button_index] }
    let(:interaction) do
      Fabricate(
        :chat_message_interaction,
        user: clicking_user,
        message: message,
        action: button.deep_dup,
      )
    end
    let(:params) { { interaction_id: interaction.id } }

    before do
      SiteSetting.chat_enabled = true
      SiteSetting.enable_discourse_workflows = true
      SiteSetting.enable_names = true
    end

    context "when the plugin is disabled" do
      before { SiteSetting.enable_discourse_workflows = false }

      it { is_expected.to fail_a_policy(:workflows_enabled) }
    end

    context "when the contract is invalid" do
      let(:params) { {} }

      it { is_expected.to fail_a_contract }
    end

    context "when the persisted interaction does not exist" do
      let(:params) { { interaction_id: -1 } }

      it { is_expected.to fail_to_find_a_model(:interaction) }
    end

    context "when the signed action points to a missing execution" do
      let(:missing_action_id) do
        DiscourseWorkflows::InteractiveResume.action_id(
          execution_id: 999_999,
          resume_token: "missing",
          action: "button_0",
        )
      end
      let(:interaction) do
        Fabricate(
          :chat_message_interaction,
          user: clicking_user,
          message: Fabricate(:chat_message, chat_channel: channel),
          action: {
            "action_id" => missing_action_id,
            "value" => "approve",
          },
        )
      end

      it { is_expected.to fail_to_find_a_model(:resolved_interaction) }
    end

    context "when the action token is stale" do
      let(:stale_action_id) do
        DiscourseWorkflows::InteractiveResume.action_id(
          execution_id: execution.id,
          resume_token: "stale-token",
          action: "button_0",
        )
      end
      let(:interaction) do
        Fabricate(
          :chat_message_interaction,
          user: clicking_user,
          message: message,
          action: button.merge("action_id" => stale_action_id),
        )
      end

      it { is_expected.to fail_to_find_a_model(:resolved_interaction) }
    end

    context "when the signed index is not configured" do
      let(:invalid_action_id) do
        DiscourseWorkflows::InteractiveResume.action_id(
          execution_id: execution.id,
          resume_token: execution.resume_token,
          action: "button_9",
        )
      end
      let(:interaction) do
        Fabricate(
          :chat_message_interaction,
          user: clicking_user,
          message: message,
          action: button.merge("action_id" => invalid_action_id),
        )
      end

      it { is_expected.to fail_to_find_a_model(:resolved_interaction) }
    end

    context "when the interaction message belongs to another channel" do
      fab!(:other_channel, :chat_channel)

      let(:interaction) do
        Fabricate(
          :chat_message_interaction,
          user: clicking_user,
          message:
            Fabricate(
              :chat_message,
              chat_channel: other_channel,
              user: Discourse.system_user,
              blocks: message.blocks,
            ),
          action: button.deep_dup,
        )
      end

      it { is_expected.to fail_to_find_a_model(:resolved_interaction) }
    end

    context "when the persisted action value was tampered with" do
      let(:interaction) do
        Fabricate(
          :chat_message_interaction,
          user: clicking_user,
          message: message,
          action: button.merge("value" => "tampered"),
        )
      end

      it { is_expected.to fail_to_find_a_model(:resolved_interaction) }
    end

    context "when the message was trashed after the interaction was persisted" do
      before do
        interaction
        message.trash!(clicking_user)
      end

      it { is_expected.to fail_to_find_a_model(:resolved_interaction) }
    end

    context "when the channel was trashed after the interaction was persisted" do
      before do
        interaction
        channel.trash!(clicking_user)
      end

      it { is_expected.to fail_to_find_a_model(:resolved_interaction) }
    end

    context "when given an interaction for a versionless V1 waiting node" do
      let(:node_version) { nil }
      let(:approval_configuration) do
        {
          "message" => "Approve?",
          "approve_label" => "Yes",
          "deny_label" => "No",
          "channel_id" => channel.id.to_s,
        }
      end

      it { is_expected.to fail_to_find_a_model(:resolved_interaction) }
    end

    context "with a V2 waiting node" do
      let(:button_index) { 1 }

      it "returns the configured value, channel, and clicking user as one paired item" do
        expect(result).to run_successfully

        expected_user = {
          "id" => clicking_user.id,
          "username" => clicking_user.username,
          "name" => clicking_user.name,
          "avatar_template" => clicking_user.avatar_template,
        }
        expected_channel = {
          "id" => channel.id,
          "title" => channel.title(clicking_user),
          "slug" => channel.slug,
          "chatable_type" => channel.chatable_type,
          "chatable_id" => channel.chatable_id,
        }

        execution.reload
        expect(execution.execution_data.context_data["Wait"]).to eq(
          [
            {
              "json" => {
                "value" => "needs:changes",
                "channel" => expected_channel,
                "user" => expected_user,
              },
              "pairedItem" => {
                "item" => 0,
              },
            },
          ],
        )
        expect(execution.execution_data.context_data.dig("After", 0, "json")).to include(
          "value" => "needs:changes",
          "current_user_id" => clicking_user.id,
        )
      end
    end

    it "allows only one concurrent persisted interaction to claim the execution" do
      second_user = Fabricate(:user)
      second_interaction =
        Fabricate(
          :chat_message_interaction,
          user: second_user,
          message: message,
          action: button.deep_dup,
        )

      ready = Queue.new
      start = Queue.new
      interaction_ids = [interaction.id, second_interaction.id]
      threads =
        interaction_ids.map do |interaction_id|
          Thread.new do
            ready << true
            start.pop
            described_class.call(params: { interaction_id: interaction_id })
          end
        end
      interaction_ids.length.times { ready.pop }
      interaction_ids.length.times { start << true }
      results = threads.map(&:value)

      expect(results.count(&:success?)).to eq(1)
      expect(results.count(&:failure?)).to eq(1)
      expect(execution.reload.execution_data.context_data.dig("After", 0, "json")).to include(
        "current_user_id" => satisfy { |id| [clicking_user.id, second_user.id].include?(id) },
      )
    end
  end
end
