# frozen_string_literal: true

RSpec.describe Chat::SearchMessage do
  describe ".call" do
    subject(:result) { described_class.call(**params) }

    fab!(:current_user) { Fabricate(:user) }
    fab!(:guardian) { Guardian.new(current_user) }

    fab!(:channel) { Fabricate(:chat_channel) }

    let(:params) { { guardian: guardian, params: { channel_id: channel.id, term: term } } }
    let(:term) { "test" }

    before do
      channel.add(current_user)
      SiteSetting.chat_enabled = true
      SearchIndexer.enable
    end

    context "when user can view the channel" do
      fab!(:message_1) { Fabricate(:chat_message, chat_channel: channel, message: "hello world") }
      fab!(:message_2) { Fabricate(:chat_message, chat_channel: channel, message: "test message") }
      fab!(:message_3) { Fabricate(:chat_message, chat_channel: channel, message: "another test") }

      before do
        # Ensure search data is created for messages
        [message_1, message_2, message_3].each do |message|
          SearchIndexer.index(message, force: true)
        end
      end

      it { is_expected.to be_a_success }

      it "returns matching messages" do
        expect(result.messages).to contain_exactly(message_2, message_3)
      end

      context "when term is blank" do
        let(:term) { "" }

        it { is_expected.to be_a_success }

        it "returns no messages" do
          expect(result.messages).to be_empty
        end
      end

      context "when no messages match" do
        let(:term) { "nonexistent" }

        it { is_expected.to be_a_success }

        it "returns no messages" do
          expect(result.messages).to be_empty
        end
      end

      context "with @username filter" do
        fab!(:alice) { Fabricate(:user, username: "alice") }
        fab!(:bob) { Fabricate(:user, username: "bob") }

        fab!(:alice_message_1) { Fabricate(:chat_message, chat_channel: channel, user: alice, message: "hello from alice") }
        fab!(:alice_message_2) { Fabricate(:chat_message, chat_channel: channel, user: alice, message: "testing something") }
        fab!(:bob_message) { Fabricate(:chat_message, chat_channel: channel, user: bob, message: "hello from bob") }

        before do
          [alice_message_1, alice_message_2, bob_message].each do |message|
            SearchIndexer.index(message, force: true)
          end
        end

        context "when searching with @username and term" do
          let(:term) { "@alice hello" }

          it "returns only messages from that user matching the term" do
            expect(result.messages).to contain_exactly(alice_message_1)
          end
        end

        context "when searching with @username only" do
          let(:term) { "@alice" }

          it "returns all messages from that user" do
            expect(result.messages).to contain_exactly(alice_message_1, alice_message_2)
          end
        end

        context "when searching with @me" do
          fab!(:current_user_message) { Fabricate(:chat_message, chat_channel: channel, user: current_user, message: "my message") }

          let(:term) { "@me" }

          before do
            SearchIndexer.index(current_user_message, force: true)
          end

          it "returns messages from the current user" do
            expect(result.messages).to contain_exactly(current_user_message)
          end
        end

        context "when username doesn't exist" do
          let(:term) { "@nonexistent hello" }

          it "searches for the literal @nonexistent text" do
            # Should not find messages since @nonexistent is kept in the search term
            expect(result.messages).to be_empty
          end
        end

        context "when username is case insensitive" do
          let(:term) { "@ALICE hello" }

          it "returns messages from alice regardless of case" do
            expect(result.messages).to contain_exactly(alice_message_1)
          end
        end

        context "with multiple @username filters" do
          let(:term) { "@alice @bob hello" }

          it "returns no results since no message can be from both users" do
            # Multiple @username filters create conflicting conditions
            expect(result.messages).to be_empty
          end
        end
      end

      context "with limit parameter" do
        fab!(:message_4) { Fabricate(:chat_message, chat_channel: channel, message: "test four") }
        fab!(:message_5) { Fabricate(:chat_message, chat_channel: channel, message: "test five") }

        let(:params) { { guardian: guardian, params: { channel_id: channel.id, term: term, limit: 2 } } }

        before do
          [message_4, message_5].each do |message|
            SearchIndexer.index(message, force: true)
          end
        end

        it "limits the number of results" do
          expect(result.messages.length).to eq(2)
        end
      end
    end

    context "when user cannot view the channel" do
      fab!(:private_channel) { Fabricate(:private_category_channel) }

      let(:params) { { guardian: guardian, params: { channel_id: private_channel.id, term: term } } }

      it { is_expected.to be_a_failure }
    end

    context "when channel doesn't exist" do
      let(:params) { { guardian: guardian, params: { channel_id: -1, term: term } } }

      it { is_expected.to be_a_failure }
    end

    context "with invalid params" do
      context "when channel_id is missing" do
        let(:params) { { guardian: guardian, params: { term: term } } }

        it { is_expected.to be_a_failure }
      end

      context "when limit is too high" do
        let(:params) { { guardian: guardian, params: { channel_id: channel.id, term: term, limit: 50 } } }

        it { is_expected.to be_a_failure }
      end

      context "when limit is too low" do
        let(:params) { { guardian: guardian, params: { channel_id: channel.id, term: term, limit: 0 } } }

        it { is_expected.to be_a_failure }
      end
    end
  end
end
