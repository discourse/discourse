# frozen_string_literal: true

RSpec.describe Chat::Action::SearchMessage::ProcessSearchQuery do
  subject(:result) { described_class.call(query: query, messages: messages, guardian: guardian) }

  fab!(:current_user, :user)
  fab!(:channel, :chat_channel)
  fab!(:alice) { Fabricate(:user, username: "alice") }
  fab!(:bob) { Fabricate(:user, username: "bob") }

  let(:guardian) { Guardian.new(current_user) }
  let(:messages) { Chat::Message.joins(:chat_channel).where(chat_channel: channel) }
  let(:query) { "hello world" }

  before do
    channel.add(current_user)
    SiteSetting.chat_enabled = true
  end

  context "with no filters" do
    let(:query) { "hello world" }

    it "returns the original query as processed_query" do
      expect(result.processed_query).to eq("hello world")
    end

    it "returns empty filters array" do
      expect(result.filters).to be_empty
    end

    it "returns the original messages relation" do
      expect(result.messages).to eq(messages)
    end
  end

  context "with @username filter" do
    fab!(:alice_message) do
      Fabricate(:chat_message, chat_channel: channel, user: alice, message: "hello from alice")
    end
    fab!(:bob_message) do
      Fabricate(:chat_message, chat_channel: channel, user: bob, message: "hello from bob")
    end

    let(:query) { "@alice hello" }

    it "extracts username filter" do
      expect(result.filters).to contain_exactly([:username, "alice"])
    end

    it "removes @username from processed_query" do
      expect(result.processed_query).to eq("hello")
    end

    it "filters messages by username" do
      expect(result.messages).to contain_exactly(alice_message)
    end

    context "when username is case insensitive" do
      let(:query) { "@ALICE hello" }

      it "extracts username as-is from query" do
        expect(result.filters).to contain_exactly([:username, "ALICE"])
      end

      it "filters messages correctly regardless of case" do
        expect(result.messages).to contain_exactly(alice_message)
      end
    end

    context "when username is @me" do
      fab!(:current_user_message) do
        Fabricate(:chat_message, chat_channel: channel, user: current_user, message: "my message")
      end

      let(:query) { "@me hello" }

      it "extracts me filter" do
        expect(result.filters).to contain_exactly([:username, "me"])
      end

      it "filters messages by current user" do
        expect(result.messages).to contain_exactly(current_user_message)
      end
    end

    context "when username doesn't exist" do
      let(:query) { "@nonexistent hello" }

      it "extracts the filter" do
        expect(result.filters).to contain_exactly([:username, "nonexistent"])
      end

      it "returns no messages" do
        expect(result.messages).to be_empty
      end
    end

    context "with multiple @username filters" do
      let(:query) { "@alice @bob hello" }

      it "extracts both username filters" do
        expect(result.filters).to contain_exactly([:username, "alice"], [:username, "bob"])
      end

      it "removes both @usernames from processed_query" do
        expect(result.processed_query).to eq("hello")
      end

      it "returns no messages since one message can't be from both users" do
        expect(result.messages).to be_empty
      end
    end
  end

  context "with #channel filter" do
    fab!(:other_channel) { Fabricate(:chat_channel, slug: "other-channel") }
    fab!(:channel_message) do
      Fabricate(:chat_message, chat_channel: channel, message: "message in main channel")
    end
    fab!(:other_channel_message) do
      Fabricate(:chat_message, chat_channel: other_channel, message: "message in other channel")
    end

    let(:messages) { Chat::Message.joins(:chat_channel) }
    let(:query) { "##{channel.slug} hello" }

    before { other_channel.add(current_user) }

    it "extracts channel filter" do
      expect(result.filters).to contain_exactly([:channel, channel.slug])
    end

    it "removes #channel from processed_query" do
      expect(result.processed_query).to eq("hello")
    end

    it "filters messages by channel" do
      expect(result.messages).to contain_exactly(channel_message)
    end

    context "when channel slug is case insensitive" do
      let(:query) { "##{channel.slug.upcase} hello" }

      it "extracts slug as-is from query" do
        expect(result.filters).to contain_exactly([:channel, channel.slug.upcase])
      end

      it "filters messages correctly regardless of case" do
        expect(result.messages).to contain_exactly(channel_message)
      end
    end

    context "when channel doesn't exist" do
      let(:query) { "#nonexistent hello" }

      it "extracts the filter" do
        expect(result.filters).to contain_exactly([:channel, "nonexistent"])
      end

      it "returns no messages" do
        expect(result.messages).to be_empty
      end
    end

    context "when user cannot view the channel" do
      fab!(:private_channel, :private_category_channel)
      fab!(:private_message) do
        Fabricate(:chat_message, chat_channel: private_channel, message: "private message")
      end

      let(:query) { "##{private_channel.slug} hello" }

      it "returns no messages" do
        expect(result.messages).to be_empty
      end
    end
  end

  context "with mixed filters and terms" do
    fab!(:alice_message) do
      Fabricate(:chat_message, chat_channel: channel, user: alice, message: "hello world")
    end

    let(:query) { "hello @alice world ##{channel.slug}" }

    it "extracts all filters" do
      expect(result.filters).to contain_exactly([:username, "alice"], [:channel, channel.slug])
    end

    it "removes all filter terms from processed_query" do
      expect(result.processed_query).to eq("hello world")
    end
  end

  context "with empty query" do
    let(:query) { "" }

    it "returns empty processed_query" do
      expect(result.processed_query).to eq("")
    end

    it "returns empty filters" do
      expect(result.filters).to be_empty
    end
  end

  context "with blank query" do
    let(:query) { "   " }

    it "returns empty processed_query" do
      expect(result.processed_query).to eq("")
    end

    it "returns empty filters" do
      expect(result.filters).to be_empty
    end
  end

  context "with filter only query" do
    fab!(:alice_message) do
      Fabricate(:chat_message, chat_channel: channel, user: alice, message: "anything")
    end

    let(:query) { "@alice" }

    it "returns empty processed_query" do
      expect(result.processed_query).to eq("")
    end

    it "extracts the filter" do
      expect(result.filters).to contain_exactly([:username, "alice"])
    end

    it "filters messages correctly" do
      expect(result.messages).to contain_exactly(alice_message)
    end
  end

  context "with extra whitespace" do
    fab!(:alice_message) do
      Fabricate(:chat_message, chat_channel: channel, user: alice, message: "hello world")
    end

    let(:query) { "  hello   @alice   world  " }

    it "normalizes whitespace in processed_query" do
      expect(result.processed_query).to eq("hello world")
    end

    it "extracts filters correctly" do
      expect(result.filters).to contain_exactly([:username, "alice"])
    end
  end
end
