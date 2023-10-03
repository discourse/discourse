# frozen_string_literal: true

RSpec.describe Chat::SearchChatable do
  describe ".call" do
    subject(:result) { described_class.call(params) }

    fab!(:current_user) { Fabricate(:user, username: "bob-user") }
    fab!(:sam) { Fabricate(:user, username: "sam-user") }
    fab!(:charlie) { Fabricate(:user, username: "charlie-user") }
    fab!(:channel_1) { Fabricate(:chat_channel, name: "bob-channel") }
    fab!(:channel_2) { Fabricate(:direct_message_channel, users: [current_user, sam]) }
    fab!(:channel_3) { Fabricate(:direct_message_channel, users: [current_user, sam, charlie]) }
    fab!(:channel_4) { Fabricate(:direct_message_channel, users: [sam, charlie]) }

    let(:guardian) { Guardian.new(current_user) }
    let(:params) { { guardian: guardian, term: term } }
    let(:term) { "" }

    before do
      SiteSetting.direct_message_enabled_groups = Group::AUTO_GROUPS[:everyone]
      # simpler user search without having to worry about user search data
      SiteSetting.enable_names = false
      return unless guardian.can_create_direct_message?
      channel_1.add(current_user)
    end

    context "when all steps pass" do
      it "sets the service result as successful" do
        expect(result).to be_a_success
      end

      it "returns chatables" do
        expect(result.memberships).to contain_exactly(
          channel_1.membership_for(current_user),
          channel_2.membership_for(current_user),
          channel_3.membership_for(current_user),
        )
        expect(result.category_channels).to contain_exactly(channel_1)
        expect(result.direct_message_channels).to contain_exactly(channel_2, channel_3)
        expect(result.users).to include(current_user, sam)
      end

      it "doesn’t return direct message of other users" do
        expect(result.direct_message_channels).to_not include(channel_4)
      end

      context "with private channel" do
        fab!(:private_channel_1) { Fabricate(:private_category_channel, name: "private") }
        let(:term) { "#private" }

        it "doesn’t return category channels you can't access" do
          expect(result.category_channels).to_not include(private_channel_1)
        end
      end

      context "when public channels are disabled" do
        it "does not return category channels" do
          SiteSetting.enable_public_channels = false

          expect(described_class.call(params).category_channels).to be_blank
        end
      end
    end

    context "when term is prefixed with #" do
      let(:term) { "#" }

      it "doesn’t return users" do
        expect(result.users).to be_blank
        expect(result.category_channels).to contain_exactly(channel_1)
        expect(result.direct_message_channels).to contain_exactly(channel_2, channel_3)
      end
    end

    context "when term is prefixed with @" do
      let(:term) { "@" }

      it "doesn’t return channels" do
        expect(result.users).to include(current_user, sam)
        expect(result.category_channels).to be_blank
        expect(result.direct_message_channels).to be_blank
      end
    end

    context "when filtering" do
      context "with full match" do
        let(:term) { "bob" }

        it "returns matching channels" do
          expect(result.users).to contain_exactly(current_user)
          expect(result.category_channels).to contain_exactly(channel_1)
          expect(result.direct_message_channels).to contain_exactly(channel_2, channel_3)
        end
      end

      context "with partial match" do
        let(:term) { "cha" }

        it "returns matching channels" do
          expect(result.users).to contain_exactly(charlie)
          expect(result.category_channels).to contain_exactly(channel_1)
          expect(result.direct_message_channels).to contain_exactly(channel_3)
        end
      end
    end

    context "when filtering with non existing term" do
      let(:term) { "xxxxxxxxxx" }

      it "returns matching channels" do
        expect(result.users).to be_blank
        expect(result.category_channels).to be_blank
        expect(result.direct_message_channels).to be_blank
      end
    end

    context "when filtering with @prefix" do
      let(:term) { "@bob" }

      it "returns matching channels" do
        expect(result.users).to contain_exactly(current_user)
        expect(result.category_channels).to be_blank
        expect(result.direct_message_channels).to be_blank
      end
    end

    context "when filtering with #prefix" do
      let(:term) { "#bob" }

      it "returns matching channels" do
        expect(result.users).to be_blank
        expect(result.category_channels).to contain_exactly(channel_1)
        expect(result.direct_message_channels).to contain_exactly(channel_2, channel_3)
      end
    end

    context "when current user can't created direct messages" do
      let(:term) { "@bob" }

      before { SiteSetting.direct_message_enabled_groups = Group::AUTO_GROUPS[:staff] }

      it "doesn’t return users" do
        expect(result.users).to be_blank
      end
    end
  end
end
