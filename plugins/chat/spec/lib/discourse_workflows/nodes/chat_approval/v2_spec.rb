# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Nodes::ChatApproval::V2 do
  fab!(:channel, :chat_channel)
  fab!(:execution, :discourse_workflows_execution)

  before { SiteSetting.chat_enabled = true }

  describe "node contract" do
    it "registers as the latest version while retaining V1 as the versionless default" do
      expect(described_class.identifier).to eq("action:chat_approval")
      expect(described_class.version).to eq("2.0")
      expect(DiscourseWorkflows::Registry.latest_version(described_class.identifier)).to eq("2.0")
      expect(DiscourseWorkflows::Registry.find_node_type(described_class.identifier)).to eq(
        DiscourseWorkflows::Nodes::ChatApproval::V1,
      )
      expect(
        DiscourseWorkflows::Registry.find_node_type(described_class.identifier, version: "2.0"),
      ).to eq(described_class)
    end

    it "declares editable label and value rows with Chat's collection limits" do
      buttons = described_class.property_schema.fetch(:buttons)

      expect(buttons).to include(
        type: :fixed_collection,
        required: true,
        max_items: 10,
        default: described_class.default_buttons,
      )
      expect(buttons.dig(:type_options, :sortable)).to eq(true)
      expect(buttons.dig(:options, 0, :values, :label)).to include(
        type: :string,
        required: true,
        no_data_expression: true,
      )
      expect(buttons.dig(:options, 0, :values, :value)).to include(
        type: :string,
        required: true,
        no_data_expression: true,
      )
      expect(described_class.property_schema.fetch(:timeout_action)).to include(
        options: %w[continue fail],
        default: "continue",
      )
    end

    it "uses localized Approve and Deny defaults" do
      expect(described_class.default_button_rows).to eq(
        [
          {
            "label" => I18n.t("discourse_workflows.chat_approval.default_approve_label"),
            "value" => "approve",
          },
          {
            "label" => I18n.t("discourse_workflows.chat_approval.default_deny_label"),
            "value" => "deny",
          },
        ],
      )
    end

    it "exposes the exact click output and timeout continuation contracts" do
      input_schema = DiscourseWorkflows::Schema::POST_SCHEMA
      expected_properties = {
        "value" => {
          "type" => "string",
        },
        "channel" => {
          "type" => "object",
          "properties" => Chat::WorkflowChannelSerializer::PROPERTIES,
        },
        "user" => {
          "type" => "object",
          "properties" => DiscourseWorkflows::Schema::BASIC_USER_PROPERTIES,
        },
      }

      expect(described_class::CLICK_OUTPUT_SCHEMA.fetch("properties")).to eq(expected_properties)
      expect(described_class.output_schemas({})).to eq([described_class::CLICK_OUTPUT_SCHEMA])
      expect(
        described_class.output_schemas(
          { "timeout_minutes" => "30" },
          input_schemas: [input_schema],
        ),
      ).to eq(
        [DiscourseWorkflows::Schema.union(input_schema, described_class::CLICK_OUTPUT_SCHEMA)],
      )
      expect(
        described_class.output_schemas(
          { "timeout_minutes" => "30", "timeout_action" => "fail" },
          input_schemas: [input_schema],
        ),
      ).to eq([described_class::CLICK_OUTPUT_SCHEMA])
    end
  end

  describe ".validate_configuration" do
    def errors_for(button_rows)
      errors = ActiveModel::Errors.new(Object.new)
      described_class.validate_configuration({ "buttons" => { "values" => button_rows } }, errors)
      errors
    end

    it "accepts one through ten buttons at the label and value length boundaries" do
      one_button = [{ "label" => "L" * 75, "value" => "v" * 2000 }]
      ten_buttons =
        Array.new(10) { |index| { "label" => "Button #{index}", "value" => index.to_s } }

      expect(errors_for(one_button)).to be_empty
      expect(errors_for(ten_buttons)).to be_empty
    end

    it "accepts duplicate and punctuation-rich values" do
      rows = [
        { "label" => "First", "value" => "review:later" },
        { "label" => "Second", "value" => "review:later" },
      ]

      expect(errors_for(rows)).to be_empty
    end

    it "rejects empty, excessive, and oversized button collections", :aggregate_failures do
      valid_row = { "label" => "Choose", "value" => "choice" }

      expect(errors_for([])[:base]).to include(
        I18n.t("discourse_workflows.errors.chat_approval.buttons_required"),
      )
      expect(errors_for(Array.new(11) { valid_row })[:base]).to include(
        I18n.t("discourse_workflows.errors.chat_approval.too_many_buttons", max: 10),
      )
      expect(errors_for([{ "label" => "L" * 76, "value" => "choice" }])[:base]).to include(
        I18n.t(
          "discourse_workflows.errors.chat_approval.button_label_too_long",
          position: 1,
          max: 75,
        ),
      )
      expect(errors_for([{ "label" => "Choose", "value" => "v" * 2001 }])[:base]).to include(
        I18n.t(
          "discourse_workflows.errors.chat_approval.button_value_too_long",
          position: 1,
          max: 2000,
        ),
      )
      expect(errors_for([{ "label" => "", "value" => "choice" }])[:base]).to include(
        I18n.t("discourse_workflows.errors.chat_approval.button_label_required", position: 1),
      )
      expect(errors_for([{ "label" => "Choose", "value" => "" }])[:base]).to include(
        I18n.t("discourse_workflows.errors.chat_approval.button_value_required", position: 1),
      )
    end
  end

  describe ".valid_interaction?" do
    it "rejects absent and malformed channel identifiers", :aggregate_failures do
      interaction = Fabricate(:chat_message_interaction, action: {})
      parameters = { "buttons" => described_class.default_buttons }

      expect(
        described_class.valid_interaction?(interaction, action: "button_0", parameters:),
      ).to eq(false)
      expect(
        described_class.valid_interaction?(
          interaction,
          action: "button_0",
          parameters: parameters.merge("channel_id" => "not-a-channel"),
        ),
      ).to eq(false)
    end
  end

  describe "#execute" do
    let(:resume_token) { SecureRandom.uuid }
    let(:sandbox) { DiscourseWorkflows::JsSandbox.new({}) }

    after { sandbox.dispose }

    def build_v2_exec_ctx(
      config,
      runtime_state: DiscourseWorkflows::Executor::NodeExecutionContext::RuntimeState.new
    )
      resolver = DiscourseWorkflows::ExpressionResolver.new({ "$json" => {} }, sandbox: sandbox)
      DiscourseWorkflows::Executor::NodeExecutionContext.new(
        input_items: [{ "json" => { "request_id" => 42 } }],
        resolver: resolver,
        parameters: config,
        property_schema: described_class.property_schema,
        execution_id: execution.id,
        node_id: "node_abc",
        resume_token: resume_token,
        runtime_state: runtime_state,
      )
    end

    it "renders the default buttons when the buttons parameter is missing" do
      config = { "message" => "Choose", "channel_id" => channel.id.to_s }
      instance = described_class.new(parameters: config)

      instance.execute(build_v2_exec_ctx(config))

      buttons = Chat::Message.last.blocks.first["elements"]
      expect(buttons.map { |button| [button.dig("text", "text"), button["value"]] }).to eq(
        [%w[Approve approve], %w[Deny deny]],
      )
    end

    it "creates indexed signed actions for custom, duplicate, punctuation, and long values" do
      long_value = "v" * 2000
      rows = [
        { "label" => "Review later", "value" => "review:later" },
        { "label" => "Same outcome", "value" => "review:later" },
        { "label" => "Long outcome", "value" => long_value },
      ]
      config = {
        "message" => "Choose",
        "buttons" => {
          "values" => rows,
        },
        "channel_id" => channel.id.to_s,
      }
      instance = described_class.new(parameters: config)

      instance.execute(build_v2_exec_ctx(config))

      buttons = Chat::Message.last.blocks.first["elements"]
      payloads =
        buttons.map do |button|
          DiscourseWorkflows::InteractiveResume.action_payload(button["action_id"])
        end
      expect(buttons.map { |button| button["value"] }).to eq(
        ["review:later", "review:later", long_value],
      )
      expect(payloads.map { |payload| payload["action"] }).to eq(%w[button_0 button_1 button_2])
      expect(buttons.map { |button| button["action_id"] }).to all(
        satisfy { |action_id| action_id.length <= 255 && !action_id.include?(long_value) },
      )
    end

    it "treats an explicitly empty button collection as invalid" do
      config = {
        "message" => "Choose",
        "buttons" => {
          "values" => [],
        },
        "channel_id" => channel.id.to_s,
      }
      instance = described_class.new(parameters: config)

      expect { instance.execute(build_v2_exec_ctx(config)) }.to raise_error(
        DiscourseWorkflows::NodeError,
        I18n.t("discourse_workflows.errors.chat_approval.buttons_required"),
      )
      expect(channel.chat_messages).to be_empty
    end

    it "passes timeout action only when an explicit timeout is configured" do
      without_timeout = {
        "message" => "Choose",
        "channel_id" => channel.id.to_s,
        "timeout_action" => "fail",
      }
      without_timeout_state = DiscourseWorkflows::Executor::NodeExecutionContext::RuntimeState.new
      described_class.new(parameters: without_timeout).execute(
        build_v2_exec_ctx(without_timeout, runtime_state: without_timeout_state),
      )

      with_timeout = without_timeout.merge("timeout_minutes" => "12")
      with_timeout_state = DiscourseWorkflows::Executor::NodeExecutionContext::RuntimeState.new
      freeze_time do
        described_class.new(parameters: with_timeout).execute(
          build_v2_exec_ctx(with_timeout, runtime_state: with_timeout_state),
        )

        expect(with_timeout_state.wait_request.waiting_until).to eq_time(12.minutes.from_now)
      end

      expect(without_timeout_state.wait_request.timeout_action).to be_nil
      expect(with_timeout_state.wait_request.timeout_action).to eq("fail")
    end
  end
end
