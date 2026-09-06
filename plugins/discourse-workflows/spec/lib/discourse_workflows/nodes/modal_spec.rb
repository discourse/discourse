# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Nodes::Modal::V1 do
  fab!(:user)
  fab!(:other_user, :user)

  let(:sandbox) { DiscourseWorkflows::JsSandbox.new({ "$json" => {} }) }
  after { sandbox.dispose }

  let(:config) do
    {
      "title" => "Approve topic?",
      "body" => "Please choose an option",
      "buttons" => {
        "values" => [
          { "label" => "Approve", "value" => "approve", "style" => "primary" },
          { "label" => "Reject", "value" => "reject", "style" => "danger" },
        ],
      },
    }
  end

  let(:execution_configuration) { config }
  let(:context_user) { user }
  let(:execution_context) do
    DiscourseWorkflows::Executor::NodeExecutionContext.new(
      input_items: [{ "json" => {} }],
      parameters: execution_configuration,
      property_schema: described_class.property_schema,
      node_context: {
      },
      resolver: DiscourseWorkflows::ExpressionResolver.new({ "$json" => {} }, sandbox: sandbox),
      user: context_user,
      execution_id: 7,
      resume_token: "tok-7",
    )
  end

  describe "#execute" do
    it "publishes the modal to the triggering user and pauses the execution" do
      allow(execution_context).to receive(:put_execution_to_wait).and_call_original

      messages =
        MessageBus.track_publish(described_class.user_channel(user.id)) do
          result = described_class.new(parameters: config).execute(execution_context)
          expect(result).to eq([execution_context.input_items])
        end

      expect(execution_context).to have_received(:put_execution_to_wait).with(nil)
      expect(messages.size).to eq(1)
      message = messages.first
      expect(message.user_ids).to eq([user.id])
      expect(message.data[:type]).to eq("show_modal")
      expect(message.data[:modal_id]).to match(/\A\h{16}\z/)
      expect(message.data[:title]).to eq("Approve topic?")
      expect(message.data[:body]).to eq("Please choose an option")

      buttons = message.data[:buttons]
      expect(buttons.map { |button| button["value"] }).to eq(%w[approve reject])
      expect(buttons.map { |button| button["label"] }).to eq(%w[Approve Reject])
      expect(buttons.map { |button| button["style"] }).to eq(%w[primary danger])
      expect(buttons.first["action_id"]).to eq(
        DiscourseWorkflows::InteractiveResume.action_id(
          execution_id: 7,
          resume_token: "tok-7",
          action: "approve",
          target_user_id: user.id,
        ),
      )
    end

    context "with a configured target user" do
      let(:execution_configuration) { config.merge("target_user" => other_user.username) }

      it "binds the target user into the action ids" do
        messages =
          MessageBus.track_publish(described_class.user_channel(other_user.id)) do
            described_class.new(parameters: execution_configuration).execute(execution_context)
          end

        action_id = messages.first.data[:buttons].first["action_id"]
        payload = DiscourseWorkflows::InteractiveResume.action_payload(action_id)
        expect(payload["target_user_id"]).to eq(other_user.id)
        expect(payload["target_user_id"]).not_to eq(user.id)
      end

      it "sends the modal to the target instead of the triggering user" do
        messages =
          MessageBus.track_publish(described_class.user_channel(other_user.id)) do
            described_class.new(parameters: execution_configuration).execute(execution_context)
          end

        expect(messages.size).to eq(1)
        expect(messages.first.user_ids).to eq([other_user.id])
      end
    end

    context "without a target user" do
      let(:context_user) { nil }

      it "raises a node error" do
        expect {
          described_class.new(parameters: config).execute(execution_context)
        }.to raise_error(
          DiscourseWorkflows::NodeError,
          I18n.t("discourse_workflows.errors.modal.no_target_user"),
        )
      end
    end

    context "with a missing configured target user" do
      let(:execution_configuration) { config.merge("target_user" => "ghost") }

      it "raises a node error" do
        expect {
          described_class.new(parameters: execution_configuration).execute(execution_context)
        }.to raise_error(
          DiscourseWorkflows::NodeError,
          I18n.t("discourse_workflows.errors.modal.user_not_found", username: "ghost"),
        )
      end
    end

    context "without buttons" do
      let(:execution_configuration) { config.merge("buttons" => { "values" => [] }) }

      it "shows an informational modal without waiting" do
        allow(execution_context).to receive(:put_execution_to_wait)

        messages =
          MessageBus.track_publish(described_class.user_channel(user.id)) do
            result =
              described_class.new(parameters: execution_configuration).execute(execution_context)
            expect(result).to eq([execution_context.input_items])
          end

        expect(execution_context).not_to have_received(:put_execution_to_wait)
        expect(messages.size).to eq(1)
        expect(messages.first.data[:buttons]).to eq([])
      end
    end
  end

  describe ".publish_close" do
    it "tells every tab of the target user to close the modal" do
      messages =
        MessageBus.track_publish(described_class.user_channel(user.id)) do
          described_class.publish_close(user.id, "abcd1234abcd1234")
        end

      expect(messages.size).to eq(1)
      message = messages.first
      expect(message.user_ids).to eq([user.id])
      expect(message.data).to eq(type: "close_modal", modal_id: "abcd1234abcd1234")
    end
  end

  describe ".button_values" do
    it "returns the configured button output values" do
      expect(described_class.button_values(config)).to eq(%w[approve reject])
    end

    it "returns an empty array when there are no buttons" do
      expect(described_class.button_values({})).to eq([])
    end
  end

  describe ".response_items" do
    it "wraps the chosen action as the node output" do
      expect(described_class.response_items(action: "approve")).to eq(
        [{ "json" => { "button" => "approve" }, "pairedItem" => { "item" => 0 } }],
      )
    end
  end
end
