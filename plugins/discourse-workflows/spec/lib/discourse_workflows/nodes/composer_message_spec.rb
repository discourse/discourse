# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Nodes::ComposerMessage::V1 do
  fab!(:user)

  let(:sandbox) { DiscourseWorkflows::JsSandbox.new({ "$json" => {} }) }
  after { sandbox.dispose }

  let(:config) { { "title" => "Food resources", "body" => "Visit [our guide](/t/1)" } }
  let(:context_user) { user }
  let(:trigger_data) do
    { "composer" => { "draft_key" => "new_topic", "session_id" => "session-1" } }
  end
  let(:execution_context) do
    DiscourseWorkflows::Executor::NodeExecutionContext.new(
      input_items: [{ "json" => { "anything" => true } }],
      parameters: config,
      property_schema: described_class.property_schema,
      resolver: DiscourseWorkflows::ExpressionResolver.new({ "$json" => {} }, sandbox: sandbox),
      flow_context: {
        "$trigger" => trigger_data,
      },
      user: context_user,
    )
  end

  describe "#execute" do
    it "publishes the message to the composer that triggered the workflow" do
      result = nil
      messages =
        MessageBus.track_publish(described_class.user_channel(user.id)) do
          result = described_class.new(parameters: config).execute(execution_context)
        end

      expect(result).to eq([execution_context.input_items])
      expect(messages.size).to eq(1)
      expect(messages.first.user_ids).to eq([user.id])
      expect(messages.first.data).to eq(
        type: "show_composer_message",
        draft_key: "new_topic",
        session_id: "session-1",
        title: "Food resources",
        body: PrettyText.cook("Visit [our guide](/t/1)"),
      )
    end

    it "sanitizes the body" do
      config["body"] = "<script>alert(1)</script>Hello"

      messages =
        MessageBus.track_publish(described_class.user_channel(user.id)) do
          described_class.new(parameters: config).execute(execution_context)
        end

      expect(messages.first.data[:body]).not_to include("<script")
    end

    context "without a user" do
      let(:context_user) { nil }

      it "raises a node error" do
        expect {
          described_class.new(parameters: config).execute(execution_context)
        }.to raise_error(
          DiscourseWorkflows::NodeError,
          I18n.t("discourse_workflows.errors.composer_message.no_user"),
        )
      end
    end

    context "when the composer trigger did not start the workflow" do
      let(:trigger_data) { { "post" => { "id" => 1 } } }

      it "raises a node error" do
        expect {
          described_class.new(parameters: config).execute(execution_context)
        }.to raise_error(
          DiscourseWorkflows::NodeError,
          I18n.t("discourse_workflows.errors.composer_message.no_composer"),
        )
      end
    end
  end
end
