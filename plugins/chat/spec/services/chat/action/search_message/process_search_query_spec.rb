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

    context "with staged user" do
      fab!(:staged_user) { Fabricate(:user, username: "staged", staged: true) }
      fab!(:staged_message) do
        Fabricate(
          :chat_message,
          chat_channel: channel,
          user: staged_user,
          message: "staged message",
        )
      end

      let(:query) { "@staged hello" }

      it "excludes messages from staged users" do
        expect(result.messages).to be_empty
      end
    end

    context "when guardian user is nil and using @me" do
      let(:guardian) { Guardian.new(nil) }
      let(:query) { "@me hello" }

      it "returns no messages" do
        expect(result.messages).to be_empty
      end
    end

    context "with username containing special characters" do
      fab!(:user_underscore) { Fabricate(:user, username: "user_underscore") }
      fab!(:message) do
        Fabricate(:chat_message, chat_channel: channel, user: user_underscore, message: "message")
      end

      let(:query) { "@user_underscore hello" }

      it "normalizes and filters correctly" do
        expect(result.messages).to contain_exactly(message)
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

    context "when guardian user is nil for private channel" do
      let(:guardian) { Guardian.new(nil) }

      fab!(:private_channel, :private_category_channel)
      fab!(:private_message) do
        Fabricate(:chat_message, chat_channel: private_channel, message: "private message")
      end

      let(:query) { "##{private_channel.slug} hello" }

      it "returns no messages" do
        expect(result.messages).to be_empty
      end
    end

    context "with channel slug containing special characters" do
      fab!(:special_channel) { Fabricate(:chat_channel, slug: "my-special-channel") }
      fab!(:message) { Fabricate(:chat_message, chat_channel: special_channel, message: "message") }

      before { special_channel.add(current_user) }

      let(:messages) { Chat::Message.joins(:chat_channel) }
      let(:query) { "#my-special-channel hello" }

      it "filters correctly with special characters" do
        expect(result.messages).to contain_exactly(message)
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

  context "for SQL query performance" do
    fab!(:user1) { Fabricate(:user, username: "user1") }
    fab!(:user2) { Fabricate(:user, username: "user2") }
    fab!(:user3) { Fabricate(:user, username: "user3") }
    fab!(:user4) { Fabricate(:user, username: "user4") }
    fab!(:user5) { Fabricate(:user, username: "user5") }
    fab!(:channel2) { Fabricate(:chat_channel, slug: "channel2") }
    fab!(:channel3) { Fabricate(:chat_channel, slug: "channel3") }

    it "executes constant number of queries regardless of filter count" do
      queries_with_no_filters =
        track_sql_queries do
          described_class.call(query: "hello", messages: messages, guardian: guardian)
        end

      queries_with_one_username =
        track_sql_queries do
          described_class.call(query: "@alice hello", messages: messages, guardian: guardian)
        end

      queries_with_three_usernames =
        track_sql_queries do
          described_class.call(
            query: "@alice @bob @user1 hello",
            messages: messages,
            guardian: guardian,
          )
        end

      queries_with_five_usernames =
        track_sql_queries do
          described_class.call(
            query: "@alice @bob @user1 @user2 @user3 hello",
            messages: messages,
            guardian: guardian,
          )
        end

      queries_with_one_channel =
        track_sql_queries do
          described_class.call(
            query: "##{channel.slug} hello",
            messages: messages,
            guardian: guardian,
          )
        end

      queries_with_three_channels =
        track_sql_queries do
          described_class.call(
            query: "##{channel.slug} #channel2 #channel3 hello",
            messages: messages,
            guardian: guardian,
          )
        end

      # No filters should not query users or channels
      expect(queries_with_no_filters.count).to eq(0)

      # Count user-related queries (excluding SCHEMA and CACHE)
      user_queries_one = queries_with_one_username.count { |q| q.include?('"users"') }
      user_queries_three = queries_with_three_usernames.count { |q| q.include?('"users"') }
      user_queries_five = queries_with_five_usernames.count { |q| q.include?('"users"') }

      # Count channel-related queries
      channel_queries_one = queries_with_one_channel.count { |q| q.include?('"chat_channels"') }
      channel_queries_three =
        queries_with_three_channels.count { |q| q.include?('"chat_channels"') }

      # Verify no N+1: query count should be constant regardless of number of filters
      expect(user_queries_one).to be > 0
      expect(user_queries_one).to eq(user_queries_three)
      expect(user_queries_three).to eq(user_queries_five)

      expect(channel_queries_one).to be > 0
      expect(channel_queries_one).to eq(channel_queries_three)
    end
  end

  context "with filter limit protection" do
    it "silently limits to 10 filters when more than 10 are provided" do
      query_with_11_filters =
        "@user1 @user2 @user3 @user4 @user5 @user6 #chan1 #chan2 #chan3 #chan4 #chan5 hello"

      result =
        described_class.call(query: query_with_11_filters, messages: messages, guardian: guardian)

      expect(result.filters.size).to eq(10)
      expect(result.processed_query).to eq("hello")
    end

    it "processes exactly 10 filters without truncation" do
      query_with_10_filters =
        "@user1 @user2 @user3 @user4 @user5 #chan1 #chan2 #chan3 #chan4 #chan5 hello"

      result =
        described_class.call(query: query_with_10_filters, messages: messages, guardian: guardian)

      expect(result.filters.size).to eq(10)
      expect(result.processed_query).to eq("hello")
    end

    it "preserves the first 10 filters when limit is exceeded" do
      query_with_12_filters =
        "@user1 @user2 @user3 @user4 @user5 @user6 @user7 #chan1 #chan2 #chan3 #chan4 #chan5 hello"

      result =
        described_class.call(query: query_with_12_filters, messages: messages, guardian: guardian)

      expect(result.filters.size).to eq(10)
      expect(result.filters.first).to eq([:username, "user1"])
      expect(result.filters.last).to eq([:channel, "chan3"])
      expect(result.processed_query).to eq("hello")
    end
  end

  context "with batch filtering" do
    fab!(:charlie) { Fabricate(:user, username: "charlie") }
    fab!(:david) { Fabricate(:user, username: "david") }
    fab!(:channel2) { Fabricate(:chat_channel, slug: "channel2") }
    fab!(:channel3) { Fabricate(:chat_channel, slug: "channel3") }

    fab!(:alice_msg) { Fabricate(:chat_message, chat_channel: channel, user: alice) }
    fab!(:bob_msg) { Fabricate(:chat_message, chat_channel: channel, user: bob) }
    fab!(:charlie_msg) { Fabricate(:chat_message, chat_channel: channel2, user: charlie) }
    fab!(:david_msg) { Fabricate(:chat_message, chat_channel: channel3, user: david) }

    before do
      channel2.add(current_user)
      channel3.add(current_user)
    end

    let(:messages) { Chat::Message.joins(:chat_channel) }

    it "correctly filters with multiple usernames" do
      result =
        described_class.call(query: "@alice @bob hello", messages: messages, guardian: guardian)

      expect(result.messages).to be_empty
    end

    it "correctly filters with multiple channels" do
      result =
        described_class.call(
          query: "##{channel.slug} #channel2 hello",
          messages: messages,
          guardian: guardian,
        )

      expect(result.messages).to be_empty
    end

    it "correctly filters with mixed username and channel filters" do
      result =
        described_class.call(
          query: "@alice ##{channel.slug} hello",
          messages: messages,
          guardian: guardian,
        )

      expect(result.messages).to contain_exactly(alice_msg)
    end
  end
end
