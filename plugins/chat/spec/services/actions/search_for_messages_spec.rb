# frozen_string_literal: true

RSpec.describe Chat::Action::SearchForMessages do
  describe ".call" do
    subject(:action) { described_class.call(guardian:, params:, channel:) }

    fab!(:current_user, :user)
    fab!(:channel, :chat_channel)
    fab!(:message_1) { Fabricate(:chat_message, chat_channel: channel, message: "hello world") }
    fab!(:message_2) { Fabricate(:chat_message, chat_channel: channel, message: "test message") }
    fab!(:message_3) { Fabricate(:chat_message, chat_channel: channel, message: "another test") }

    let(:guardian) { current_user.guardian }
    let(:params) { Chat::SearchMessage::Contract.new(args) }
    let(:args) { { limit: 20, offset: 0, query: } }
    let(:query) { "test" }
    let(:messages) { action[:messages] }

    before do
      SearchIndexer.enable
      SiteSetting.chat_enabled = true
      channel.add(current_user)
      [message_1, message_2, message_3].each { SearchIndexer.index(_1, force: true) }
    end

    it "returns matching messages" do
      expect(messages).to contain_exactly(message_2, message_3)
    end

    context "when no messages match" do
      let(:query) { "nonexistent" }

      it "returns no messages" do
        expect(messages).to be_empty
      end
    end

    context "with @username filter" do
      fab!(:alice) { Fabricate(:user, username: "alice") }
      fab!(:bob) { Fabricate(:user, username: "bob") }
      fab!(:alice_message_1) do
        Fabricate(:chat_message, chat_channel: channel, user: alice, message: "hello from alice")
      end
      fab!(:alice_message_2) do
        Fabricate(:chat_message, chat_channel: channel, user: alice, message: "testing something")
      end
      fab!(:bob_message) do
        Fabricate(:chat_message, chat_channel: channel, user: bob, message: "hello from bob")
      end

      before do
        [alice_message_1, alice_message_2, bob_message].each do
          SearchIndexer.index(_1, force: true)
        end
      end

      context "when searching with @username and term" do
        let(:query) { "@alice hello" }

        it "returns only messages from that user matching the term" do
          expect(messages).to contain_exactly(alice_message_1)
        end
      end

      context "when searching with @username only" do
        let(:query) { "@alice" }

        it "returns all messages from that user" do
          expect(messages).to contain_exactly(alice_message_1, alice_message_2)
        end
      end

      context "when searching with @me" do
        fab!(:current_user_message) do
          Fabricate(:chat_message, chat_channel: channel, user: current_user, message: "my message")
        end

        let(:query) { "@me" }

        before { SearchIndexer.index(current_user_message, force: true) }

        it "returns messages from the current user" do
          expect(messages).to contain_exactly(current_user_message)
        end
      end

      context "when username doesn't exist" do
        let(:query) { "@nonexistent hello" }

        it "searches for the literal @nonexistent text" do
          expect(messages).to be_empty
        end
      end

      context "when username is upcase" do
        let(:query) { "@ALICE hello" }

        it "returns messages from alice regardless of case" do
          expect(messages).to contain_exactly(alice_message_1)
        end
      end

      context "with multiple @username filters" do
        let(:query) { "@alice @bob hello" }

        it "returns no results since no message can be from both users" do
          expect(messages).to be_empty
        end
      end
    end

    context "with limit parameter" do
      fab!(:message_4) { Fabricate(:chat_message, chat_channel: channel, message: "test four") }
      fab!(:message_5) { Fabricate(:chat_message, chat_channel: channel, message: "test five") }

      before do
        args[:limit] = 2
        [message_4, message_5].each { SearchIndexer.index(_1, force: true) }
      end

      it "limits the number of results" do
        expect(messages.size).to eq(2)
      end
    end

    context "with pagination" do
      fab!(:message_4) { Fabricate(:chat_message, chat_channel: channel, message: "test four") }
      fab!(:message_5) { Fabricate(:chat_message, chat_channel: channel, message: "test five") }
      fab!(:message_6) { Fabricate(:chat_message, chat_channel: channel, message: "test six") }

      before { [message_4, message_5, message_6].each { SearchIndexer.index(_1, force: true) } }

      context "with offset parameter" do
        let(:all_results) do
          described_class.call(
            guardian:,
            channel:,
            params: Chat::SearchMessage::Contract.new(query:),
          )[
            :messages
          ]
        end

        before { args[:offset] = 2 }

        it "skips the specified number of results" do
          expect(messages).to eq(all_results.drop(2))
        end
      end

      context "with has_more indicator" do
        context "when there are more results" do
          before { args[:limit] = 2 }

          it "sets has_more to true" do
            expect(action).to include(has_more: true, limit: 2)
          end
        end

        context "when there are no more results" do
          before { args[:limit] = 10 }

          it "sets has_more to false" do
            expect(action).to include(has_more: false, limit: 10)
          end
        end

        context "when offset is used" do
          before do
            args[:limit] = 2
            args[:offset] = 3
          end

          it "sets has_more correctly based on remaining results" do
            expect(action).to include(has_more: false, limit: 2, offset: 3)
          end
        end
      end

      context "with combined offset and limit" do
        let(:all_results) do
          described_class.call(
            guardian:,
            channel:,
            params: Chat::SearchMessage::Contract.new(query:),
          )[
            :messages
          ]
        end

        before do
          args[:offset] = 1
          args[:limit] = 2
        end

        it "returns the correct page of results" do
          expect(messages).to eq(all_results[1..2])
        end
      end
    end

    context "with exclude_threads parameter" do
      fab!(:original_message) do
        Fabricate(:chat_message, chat_channel: channel, message: "original test message")
      end
      fab!(:thread) { Fabricate(:chat_thread, channel:, original_message: original_message) }
      fab!(:thread_reply) do
        Fabricate(:chat_message, chat_channel: channel, thread:, message: "thread reply test")
      end
      fab!(:regular_message) do
        Fabricate(:chat_message, chat_channel: channel, message: "regular test message")
      end

      before do
        [original_message, thread_reply, regular_message].each do
          SearchIndexer.index(_1, force: true)
        end
      end

      context "when exclude_threads is false (default)" do
        before { args[:exclude_threads] = false }

        it "includes all matching messages including thread replies" do
          expect(messages).to include(original_message, thread_reply, regular_message)
        end
      end

      context "when exclude_threads is true" do
        before { args[:exclude_threads] = true }

        it "excludes thread replies but keeps original thread messages and regular messages" do
          expect(messages).to include(original_message, regular_message)
          expect(messages).not_to include(thread_reply)
        end
      end
    end

    context "when channel is not provided (global search)" do
      subject(:action) { described_class.call(guardian:, params:, channel: nil) }

      fab!(:channel_2, :chat_channel)
      fab!(:private_channel, :private_category_channel)
      fab!(:channel_1_message) do
        Fabricate(:chat_message, chat_channel: channel, message: "global search test")
      end
      fab!(:channel_2_message) do
        Fabricate(:chat_message, chat_channel: channel_2, message: "another global test")
      end
      fab!(:private_channel_message) do
        Fabricate(:chat_message, chat_channel: private_channel, message: "private global test")
      end

      let(:query) { "global" }

      before do
        channel_2.add(current_user)
        [channel_1_message, channel_2_message, private_channel_message].each do
          SearchIndexer.index(_1, force: true)
        end
      end

      it "returns messages from multiple accessible channels" do
        expect(messages).to contain_exactly(channel_1_message, channel_2_message)
      end

      it "excludes messages from inaccessible channels" do
        expect(messages).not_to include(private_channel_message)
      end

      it "searches across all accessible channels" do
        expect(messages.map(&:chat_channel)).to contain_exactly(channel, channel_2)
      end
    end
  end
end
