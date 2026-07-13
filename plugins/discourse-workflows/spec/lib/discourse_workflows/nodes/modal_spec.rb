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

  def build_exec_ctx(configuration, ctx_user: nil, execution_id: 7, resume_token: "tok-7")
    DiscourseWorkflows::Executor::NodeExecutionContext.new(
      input_items: [{ "json" => {} }],
      parameters: configuration,
      property_schema: described_class.property_schema,
      node_context: {
      },
      resolver: DiscourseWorkflows::ExpressionResolver.new({ "$json" => {} }, sandbox: sandbox),
      user: ctx_user,
      execution_id: execution_id,
      resume_token: resume_token,
    )
  end

  describe "#execute" do
    it "publishes the modal to the triggering user and pauses the execution" do
      exec_ctx = build_exec_ctx(config, ctx_user: user)
      allow(exec_ctx).to receive(:put_execution_to_wait).and_call_original

      messages =
        MessageBus.track_publish(described_class.user_channel(user.id)) do
          result = described_class.new(parameters: config).execute(exec_ctx)
          expect(result).to eq([exec_ctx.input_items])
        end

      expect(exec_ctx).to have_received(:put_execution_to_wait).with(nil)
      expect(messages.size).to eq(1)
      message = messages.first
      expect(message.user_ids).to eq([user.id])
      expect(message.data[:type]).to eq("show_modal")
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

    it "binds the target user into the action ids so another user's token differs" do
      configuration = config.merge("target_user" => other_user.username)
      exec_ctx = build_exec_ctx(configuration, ctx_user: user)

      messages =
        MessageBus.track_publish(described_class.user_channel(other_user.id)) do
          described_class.new(parameters: configuration).execute(exec_ctx)
        end

      action_id = messages.first.data[:buttons].first["action_id"]
      payload = DiscourseWorkflows::InteractiveResume.action_payload(action_id)
      expect(payload["target_user_id"]).to eq(other_user.id)
      expect(payload["target_user_id"]).not_to eq(user.id)
    end

    it "sends the modal to a configured target user instead of the triggering user" do
      configuration = config.merge("target_user" => other_user.username)
      exec_ctx = build_exec_ctx(configuration, ctx_user: user)

      messages =
        MessageBus.track_publish(described_class.user_channel(other_user.id)) do
          described_class.new(parameters: configuration).execute(exec_ctx)
        end

      expect(messages.size).to eq(1)
      expect(messages.first.user_ids).to eq([other_user.id])
    end

    it "raises when no target user can be resolved" do
      exec_ctx = build_exec_ctx(config, ctx_user: nil)

      expect { described_class.new(parameters: config).execute(exec_ctx) }.to raise_error(
        DiscourseWorkflows::NodeError,
        I18n.t("discourse_workflows.errors.modal.no_target_user"),
      )
    end

    it "raises when the configured target user does not exist" do
      configuration = config.merge("target_user" => "ghost")
      exec_ctx = build_exec_ctx(configuration, ctx_user: user)

      expect { described_class.new(parameters: configuration).execute(exec_ctx) }.to raise_error(
        DiscourseWorkflows::NodeError,
        I18n.t("discourse_workflows.errors.modal.user_not_found", username: "ghost"),
      )
    end

    it "shows an informational modal without waiting when there are no buttons" do
      configuration = config.merge("buttons" => { "values" => [] })
      exec_ctx = build_exec_ctx(configuration, ctx_user: user)
      allow(exec_ctx).to receive(:put_execution_to_wait)

      messages =
        MessageBus.track_publish(described_class.user_channel(user.id)) do
          result = described_class.new(parameters: configuration).execute(exec_ctx)
          expect(result).to eq([exec_ctx.input_items])
        end

      expect(exec_ctx).not_to have_received(:put_execution_to_wait)
      expect(messages.size).to eq(1)
      expect(messages.first.data[:buttons]).to eq([])
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
