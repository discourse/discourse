# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Nodes::SendChatMessage::V1 do
  fab!(:channel, :chat_channel)

  before { SiteSetting.chat_enabled = true }

  describe ".load_options_context" do
    fab!(:other_channel) { Fabricate(:chat_channel, name: "Announcements") }
    fab!(:closed_channel) { Fabricate(:chat_channel, name: "Closed", status: :closed) }
    fab!(:dm_channel, :direct_message_channel)

    def load_options(filter: nil)
      context =
        DiscourseWorkflows::LoadOptionsContext.new(
          method_name: "chat_channels",
          filter: filter,
          node_class: described_class,
        )

      described_class.load_options_context(context)
    end

    it "returns open public channels with id and name" do
      ids = load_options.map { |option| option[:id] }

      expect(ids).to include(channel.id, other_channel.id)
      expect(ids).not_to include(closed_channel.id, dm_channel.id)
    end

    it "falls back to category name when channel name is blank" do
      blank_channel = Fabricate(:chat_channel, name: nil)

      option = load_options.find { |opt| opt[:id] == blank_channel.id }

      expect(option[:name]).to eq(blank_channel.chatable.name)
    end

    it "filters channels by the filter term" do
      expect(load_options(filter: "announce")).to contain_exactly(
        { id: other_channel.id, name: other_channel.name },
      )
    end

    it "limits channel options after applying the filter" do
      201.times { |index| Fabricate(:chat_channel, name: "Load option channel #{index}") }
      matching_channel = Fabricate(:chat_channel, name: "Targeted workflow channel")

      expect(load_options.size).to eq(
        DiscourseWorkflows::Nodes::ChatChannelSelection::MAX_LOAD_OPTIONS,
      )
      expect(load_options(filter: "targeted")).to contain_exactly(
        { id: matching_channel.id, name: matching_channel.name },
      )
    end
  end

  describe "#execute" do
    def build_exec_ctx(input_items:, parameters:, resolver_context:)
      sandbox = DiscourseWorkflows::JsSandbox.new(resolver_context)
      resolver = DiscourseWorkflows::ExpressionResolver.new(resolver_context, sandbox: sandbox)
      exec_ctx =
        DiscourseWorkflows::Executor::NodeExecutionContext.new(
          input_items: input_items,
          resolver: resolver,
          parameters: parameters,
          property_schema: described_class.property_schema,
          node_identifier: described_class.identifier,
          resolver_context: resolver_context,
        )

      [exec_ctx, resolver, sandbox]
    end

    it "resolves message expressions for each input item" do
      input_items = [
        { "json" => { "text" => "First message" } },
        { "json" => { "text" => "Second message" } },
      ]
      parameters = { "channel_id" => channel.id.to_s, "message" => "={{ $json.text }}" }
      resolver_context = { "$json" => {} }
      exec_ctx, resolver, sandbox = build_exec_ctx(input_items:, parameters:, resolver_context:)

      output = described_class.new(parameters: parameters).execute(exec_ctx)

      expect(output.first.map { |item| item["json"]["message"] }).to eq(
        ["First message", "Second message"],
      )
      expect(channel.chat_messages.order(:id).last(2).map(&:message)).to eq(
        ["First message", "Second message"],
      )
    ensure
      resolver&.dispose
      sandbox&.dispose
    end

    it "resolves channel_id expressions" do
      input_items = [{ "json" => { "target_channel" => channel.id } }]
      parameters = {
        "channel_id" => "={{ $json.target_channel }}",
        "message" => "Hello from expression",
      }
      resolver_context = { "$json" => {} }
      exec_ctx, resolver, sandbox = build_exec_ctx(input_items:, parameters:, resolver_context:)

      described_class.new(parameters: parameters).execute(exec_ctx)

      expect(channel.chat_messages.order(:id).last.message).to eq("Hello from expression")
    ensure
      resolver&.dispose
      sandbox&.dispose
    end

    it "rejects expression-resolved channels outside the selectable channel scope" do
      closed_channel = Fabricate(:chat_channel, name: "Closed", status: :closed)
      input_items = [{ "json" => { "target_channel" => closed_channel.id } }]
      parameters = { "channel_id" => "={{ $json.target_channel }}", "message" => "Hidden target" }
      resolver_context = { "$json" => {} }
      exec_ctx, resolver, sandbox = build_exec_ctx(input_items:, parameters:, resolver_context:)

      expect { described_class.new(parameters: parameters).execute(exec_ctx) }.to raise_error(
        I18n.t(
          "discourse_workflows.errors.send_chat_message.channel_not_found",
          channel_id: closed_channel.id,
        ),
      )
      expect(closed_channel.chat_messages).to be_empty
    ensure
      resolver&.dispose
      sandbox&.dispose
    end

    it "rejects direct message channels outside the selectable channel scope" do
      dm_channel = Fabricate(:direct_message_channel)
      parameters = { "channel_id" => dm_channel.id.to_s, "message" => "Hidden target" }
      resolver_context = { "$json" => {} }
      exec_ctx, resolver, sandbox =
        build_exec_ctx(input_items: [{ "json" => {} }], parameters:, resolver_context:)

      expect { described_class.new(parameters: parameters).execute(exec_ctx) }.to raise_error(
        I18n.t(
          "discourse_workflows.errors.send_chat_message.channel_not_found",
          channel_id: dm_channel.id.to_s,
        ),
      )
      expect(dm_channel.chat_messages).to be_empty
    ensure
      resolver&.dispose
      sandbox&.dispose
    end
  end
end
