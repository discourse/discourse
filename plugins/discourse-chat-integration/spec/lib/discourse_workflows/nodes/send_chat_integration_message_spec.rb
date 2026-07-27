# frozen_string_literal: true

require_relative "../../../dummy_provider"

RSpec.describe DiscourseWorkflows::Nodes::SendChatIntegrationMessage::V1 do
  include_context "with dummy provider"

  fab!(:topic)
  fab!(:first_post) { Fabricate(:post, topic: topic) }
  fab!(:reply) { Fabricate(:post, topic: topic, post_number: 2) }

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
    end
  end

  describe "#execute" do
    def execute_node(channel_id:, input_post_id: nil, message: nil)
      parameters = { "channel_id" => channel_id.to_s }
      parameters["message"] = message if message
      input_json = {}
      input_json["post"] = { "id" => input_post_id } if input_post_id
      resolver_context = { "$json" => input_json }
      sandbox = DiscourseWorkflows::JsSandbox.new(resolver_context)
      resolver = DiscourseWorkflows::ExpressionResolver.new(resolver_context, sandbox: sandbox)
      exec_ctx =
        DiscourseWorkflows::Executor::NodeExecutionContext.new(
          input_items: [{ "json" => input_json }],
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

    it "sends the triggering post's standard notification when no message is set",
       :aggregate_failures do
      output = execute_node(channel_id: channel.id, input_post_id: reply.id)
      result = output.first.first.fetch("json")

      expect(provider.sent_messages).to contain_exactly(post: reply.id, channel: channel)
      expect(result).to include(
        "channel_id" => channel.id,
        "provider" => "dummy",
        "post_id" => reply.id,
        "custom_message" => false,
      )
      expect(result).to match_node_output_schema(described_class)
    end

    it "sends a custom ChatIntegrationReferencePost when a message is set" do
      allow(provider).to receive(:trigger_notification).and_call_original

      execute_node(channel_id: channel.id, input_post_id: reply.id, message: "Custom alert")

      expect(provider).to have_received(:trigger_notification).with(
        an_instance_of(DiscourseChatIntegration::ChatIntegrationReferencePost),
        channel,
        nil,
      )
    end

    it "sends a standalone custom message without a post", :aggregate_failures do
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
      expect(result).to include(
        "channel_id" => channel.id,
        "provider" => "dummy",
        "post_id" => nil,
        "custom_message" => true,
      )
      expect(result).to match_node_output_schema(described_class)
    end

    it "raises when neither a post nor a custom message is set" do
      expect { execute_node(channel_id: channel.id) }.to raise_error(
        DiscourseWorkflows::NodeError,
        include("A post or custom message is required"),
      )
      expect(provider.sent_messages).to be_empty
    end

    it "raises when the channel does not exist" do
      missing_id = channel.id + 1

      expect { execute_node(channel_id: missing_id, input_post_id: reply.id) }.to raise_error(
        include(missing_id.to_s),
      )
      expect(provider.sent_messages).to be_empty
    end

    it "raises when the provider is disabled" do
      SiteSetting.dummy_provider_enabled = false

      expect { execute_node(channel_id: channel.id, input_post_id: reply.id) }.to raise_error(
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

      expect { execute_node(channel_id: channel.id, input_post_id: reply.id) }.to raise_error(
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

      expect { execute_node(channel_id: channel.id, input_post_id: reply.id) }.to raise_error(
        DiscourseWorkflows::NodeError,
        include("Account inactive"),
      )
    end

    it "raises when the post does not exist" do
      expect { execute_node(channel_id: channel.id, input_post_id: -1) }.to raise_error(
        include("-1"),
      )
      expect(provider.sent_messages).to be_empty
    end

    it "does not relay a private message the chat integration user cannot see" do
      chat_user = Fabricate(:user)
      SiteSetting.chat_integration_discourse_username = chat_user.username
      pm_post = Fabricate(:post, topic: Fabricate(:private_message_topic))

      expect { execute_node(channel_id: channel.id, input_post_id: pm_post.id) }.to raise_error(
        include(pm_post.id.to_s),
      )
      expect(provider.sent_messages).to be_empty
    end

    it "does not relay a non-regular post such as a whisper" do
      SiteSetting.whispers_allowed_groups = Group::AUTO_GROUPS[:staff].to_s
      SiteSetting.chat_integration_discourse_username = Fabricate(:admin).username
      whisper = Fabricate(:post, topic: topic, post_type: Post.types[:whisper])

      expect { execute_node(channel_id: channel.id, input_post_id: whisper.id) }.to raise_error(
        include(whisper.id.to_s),
      )
      expect(provider.sent_messages).to be_empty
    end
  end
end
