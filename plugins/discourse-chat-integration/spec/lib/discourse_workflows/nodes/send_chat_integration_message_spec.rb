# frozen_string_literal: true

require_relative "../../../dummy_provider"

RSpec.describe DiscourseWorkflows::Nodes::SendChatIntegrationMessage::V1 do
  include_context "with dummy provider"

  let(:channel) { DiscourseChatIntegration::Channel.create!(provider: "dummy") }

  before do
    SiteSetting.chat_integration_enabled = true
    SiteSetting.dummy_provider_enabled = true
  end

  def load_options(filter: nil)
    context =
      DiscourseWorkflows::LoadOptionsContext.new(
        method_name: "chat_integration_channels",
        filter: filter,
        node_class: described_class,
      )

    described_class.load_options_context(context)
  end

  describe ".load_options_context" do
    it "returns each channel labelled by its provider" do
      channel # force creation before loading options

      expect(load_options).to contain_exactly({ id: channel.id, name: "dummy: " })
      expect(load_options(filter: "missing")).to be_empty
    end

    it "excludes channels for disabled providers" do
      channel # force creation before disabling the provider
      SiteSetting.dummy_provider_enabled = false

      expect(load_options).to be_empty
    end
  end

  describe ".property_schema" do
    it "preserves the selected channel label for dynamic values", :aggregate_failures do
      schema = described_class.property_schema

      expect(schema.dig(:channel_id, :ui, :dynamic_value)).to eq(:chat_channel_id)
      expect(schema.dig(:channel_id, :control_options, :set_from_option)).to eq(
        channel_name: "name",
      )
      expect(schema.dig(:channel_id, :control_options)).to include(
        action_icon: "wrench",
        action_label: "discourse_workflows.send_chat_integration_message.configure",
        action_route: "adminPlugins.show.discourse-chat-integration-providers",
        action_route_models: ["discourse-chat-integration"],
      )
      expect(schema.dig(:channel_name, :ui, :hidden)).to eq(true)
      expect(schema).not_to have_key(:post_id)
      expect(schema.dig(:message, :required)).to eq(true)
      expect(
        described_class.output_contracts.first.dig(:schema, "properties").keys,
      ).to contain_exactly("channel_id", "provider")
    end
  end

  describe "#execute" do
    def execute_node(channel_id:, message: nil)
      parameters = { "channel_id" => channel_id.to_s }
      parameters["message"] = message if message
      resolver_context = { "$json" => {} }
      sandbox = DiscourseWorkflows::JsSandbox.new(resolver_context)
      resolver = DiscourseWorkflows::ExpressionResolver.new(resolver_context, sandbox: sandbox)
      exec_ctx =
        DiscourseWorkflows::Executor::NodeExecutionContext.new(
          input_items: [{ "json" => {} }],
          resolver: resolver,
          parameters: parameters,
          property_schema: described_class.property_schema,
          node_identifier: described_class.identifier,
          resolver_context: resolver_context,
        )

      described_class.new(parameters: parameters).execute(exec_ctx)
    ensure
      resolver&.dispose
      sandbox&.dispose
    end

    it "sends a standalone message", :aggregate_failures do
      target = nil
      allow(provider).to receive(:trigger_notification) do |post, sent_channel, rule|
        target = post
        expect(sent_channel).to eq(channel)
        expect(rule).to be_nil
      end

      output = execute_node(channel_id: channel.id, message: "Custom alert")
      result = output.first.first.fetch("json")

      expect(target).to be_an_instance_of(DiscourseChatIntegration::ChatIntegrationReferencePost)
      expect(target.user).to eq(Discourse.system_user)
      expect(target.topic.title).to eq(SiteSetting.title)
      expect(target.full_url).to eq(Discourse.base_url)
      expect(target.excerpt).to eq("Custom alert")
      expect(result).to eq("channel_id" => channel.id, "provider" => "dummy")
      expect(result).to match_node_output_schema(described_class)
    end

    it "raises when the message is not set" do
      expect { execute_node(channel_id: channel.id) }.to raise_error(
        DiscourseWorkflows::NodeError,
        include("A message is required"),
      )
      expect(provider.sent_messages).to be_empty
    end

    it "raises when the channel does not exist" do
      missing_id = channel.id + 1

      expect { execute_node(channel_id: missing_id, message: "Custom alert") }.to raise_error(
        include(missing_id.to_s),
      )
      expect(provider.sent_messages).to be_empty
    end

    it "raises when the provider is disabled" do
      SiteSetting.dummy_provider_enabled = false

      expect { execute_node(channel_id: channel.id, message: "Custom alert") }.to raise_error(
        include("dummy"),
      )
      expect(provider.sent_messages).to be_empty
    end

    it "reports translated provider errors" do
      provider.set_raise_exception(
        DiscourseChatIntegration::ProviderError.new(
          info: {
            error_key: "chat_integration.provider.slack.errors.action_prohibited",
          },
        ),
      )

      expect { execute_node(channel_id: channel.id, message: "Custom alert") }.to raise_error(
        DiscourseWorkflows::NodeError,
        include("The bot does not have permission to post to that channel"),
      )
    end

    it "reports safe API error codes when no translation is available" do
      provider.set_raise_exception(
        DiscourseChatIntegration::ProviderError.new(
          info: {
            response_body: {
              error: "account_inactive",
            },
          },
        ),
      )

      expect { execute_node(channel_id: channel.id, message: "Custom alert") }.to raise_error(
        DiscourseWorkflows::NodeError,
        include("Account inactive"),
      )
    end
  end
end
