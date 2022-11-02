# frozen_string_literal: true

require "rails_helper"

describe DirectMessageChannel do
  fab!(:user1) { Fabricate(:user, username: "chatdmfellow1") }
  fab!(:user2) { Fabricate(:user, username: "chatdmuser") }
  fab!(:chat_channel) { Fabricate(:chat_channel) }

  it_behaves_like "a chatable model" do
    fab!(:chatable) { Fabricate(:direct_message_channel) }
    let(:channel_class) { DMChannel }
  end

  describe "#chat_channel_title_for_user" do
    it "returns a nicely formatted name if it's more than one user" do
      user3 = Fabricate.build(:user, username: "chatdmregent")
      direct_message_channel = Fabricate(:direct_message_channel, users: [user1, user2, user3])

      expect(direct_message_channel.chat_channel_title_for_user(chat_channel, user1)).to eq(
        I18n.t(
          "chat.channel.dm_title.multi_user",
          users: [user3, user2].map { |u| "@#{u.username}" }.join(", "),
        ),
      )
    end

    it "returns a nicely formatted truncated name if it's more than 5 users" do
      user3 = Fabricate.build(:user, username: "chatdmregent")

      users = [user1, user2, user3].concat(
        5.times.map.with_index { |i| Fabricate(:user, username: "chatdmuser#{i}") },
      )
      direct_message_channel = Fabricate(:direct_message_channel, users: users)

      expect(direct_message_channel.chat_channel_title_for_user(chat_channel, user1)).to eq(
        I18n.t(
          "chat.channel.dm_title.multi_user_truncated",
          users: users[1..5].sort_by(&:username).map { |u| "@#{u.username}" }.join(", "),
          leftover: 2,
        ),
      )
    end

    it "returns the other user's username if it's a dm to that user" do
      direct_message_channel = Fabricate(:direct_message_channel, users: [user1, user2])

      expect(direct_message_channel.chat_channel_title_for_user(chat_channel, user1)).to eq(
        I18n.t("chat.channel.dm_title.single_user", user: "@#{user2.username}"),
      )
    end

    it "returns the current user's username if it's a dm to self" do
      direct_message_channel = Fabricate(:direct_message_channel, users: [user1])

      expect(direct_message_channel.chat_channel_title_for_user(chat_channel, user1)).to eq(
        I18n.t("chat.channel.dm_title.single_user", user: "@#{user1.username}"),
      )
    end

    context "when user is deleted" do
      it "returns a placeholder username" do
        direct_message_channel = Fabricate(:direct_message_channel, users: [user1, user2])
        user2.destroy!
        direct_message_channel.reload

        expect(direct_message_channel.chat_channel_title_for_user(chat_channel, user1)).to eq(
          "@#{I18n.t("chat.deleted_chat_username")}",
        )
      end
    end
  end
end
