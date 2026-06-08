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

  describe ".load_options_context" do
    it "returns each channel labelled by its provider" do
      channel # force creation before loading options

      context =
        DiscourseWorkflows::LoadOptionsContext.new(
          method_name: "chat_integration_channels",
          filter: nil,
          node_class: described_class,
        )

      options = described_class.load_options_context(context)

      expect(options).to contain_exactly({ id: channel.id, name: "dummy: " })
    end
  end

  describe "#execute" do
    def execute_node(channel_id:, post_id:, message: nil)
      parameters = { "channel_id" => channel_id.to_s, "post_id" => post_id.to_s }
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

    it "sends the triggering post's standard notification when no message is set" do
      execute_node(channel_id: channel.id, post_id: reply.id)

      expect(provider.sent_messages).to contain_exactly(post: reply.id, channel: channel)
    end

    it "sends a custom ChatIntegrationReferencePost when a message is set" do
      allow(provider).to receive(:trigger_notification).and_call_original

      execute_node(channel_id: channel.id, post_id: reply.id, message: "Custom alert")

      expect(provider).to have_received(:trigger_notification).with(
        an_instance_of(DiscourseChatIntegration::ChatIntegrationReferencePost),
        channel,
        nil,
      )
    end

    it "raises when the channel does not exist" do
      missing_id = channel.id + 1

      expect { execute_node(channel_id: missing_id, post_id: reply.id) }.to raise_error(
        include(missing_id.to_s),
      )
      expect(provider.sent_messages).to be_empty
    end

    it "raises when the provider is disabled" do
      SiteSetting.dummy_provider_enabled = false

      expect { execute_node(channel_id: channel.id, post_id: reply.id) }.to raise_error(
        include("dummy"),
      )
      expect(provider.sent_messages).to be_empty
    end

    it "raises when the post does not exist" do
      expect { execute_node(channel_id: channel.id, post_id: -1) }.to raise_error(include("-1"))
      expect(provider.sent_messages).to be_empty
    end

    it "does not relay a private message the chat integration user cannot see" do
      chat_user = Fabricate(:user)
      SiteSetting.chat_integration_discourse_username = chat_user.username
      pm_post = Fabricate(:post, topic: Fabricate(:private_message_topic))

      expect { execute_node(channel_id: channel.id, post_id: pm_post.id) }.to raise_error(
        include(pm_post.id.to_s),
      )
      expect(provider.sent_messages).to be_empty
    end

    it "does not relay a non-regular post such as a whisper" do
      SiteSetting.whispers_allowed_groups = Group::AUTO_GROUPS[:staff].to_s
      SiteSetting.chat_integration_discourse_username = Fabricate(:admin).username
      whisper = Fabricate(:post, topic: topic, post_type: Post.types[:whisper])

      expect { execute_node(channel_id: channel.id, post_id: whisper.id) }.to raise_error(
        include(whisper.id.to_s),
      )
      expect(provider.sent_messages).to be_empty
    end
  end
end
