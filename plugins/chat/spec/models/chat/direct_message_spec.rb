# frozen_string_literal: true

describe Chat::DirectMessage do
  fab!(:user1) { Fabricate(:user, username: "chatdmfellow1") }
  fab!(:user2) { Fabricate(:user, username: "chatdmuser") }
  fab!(:chat_channel) { Fabricate(:direct_message_channel) }

  it_behaves_like "a chatable model" do
    fab!(:chatable) { Fabricate(:direct_message) }
    let(:channel_class) { Chat::DirectMessageChannel }
  end

  describe "#chat_channel_title_for_user" do
    it "returns a nicely formatted name if it's more than one user" do
      user3 = Fabricate.build(:user, username: "chatdmregent")
      direct_message = Fabricate(:direct_message, users: [user1, user2, user3])

      expect(direct_message.chat_channel_title_for_user(chat_channel, user1)).to eq(
        I18n.t(
          "chat.channel.dm_title.multi_user",
          comma_separated_usernames:
            [user3, user2].map { |u| u.username }.join(I18n.t("word_connector.comma")),
        ),
      )
    end

    it "returns a nicely formatted truncated name if it's more than 7 users" do
      user3 = Fabricate.build(:user, username: "chatdmregent")

      users = [user1, user2, user3].concat(
        6.times.map { |i| Fabricate(:user, username: "chatdmuser#{i}") },
      )
      direct_message = Fabricate(:direct_message, users: users)

      expect(direct_message.chat_channel_title_for_user(chat_channel, user1)).to eq(
        I18n.t(
          "chat.channel.dm_title.multi_user_truncated",
          comma_separated_usernames:
            users[1..6]
              .sort_by(&:username)
              .map { |u| u.username }
              .join(I18n.t("word_connector.comma")),
          count: 2,
        ),
      )
    end

    it "returns the other user's username if it's a dm to that user" do
      direct_message = Fabricate(:direct_message, users: [user1, user2])

      expect(direct_message.chat_channel_title_for_user(chat_channel, user1)).to eq(
        I18n.t("chat.channel.dm_title.single_user", username: user2.username),
      )
    end

    it "returns the current user's username if it's a dm to self" do
      direct_message = Fabricate(:direct_message, users: [user1])

      expect(direct_message.chat_channel_title_for_user(chat_channel, user1)).to eq(
        I18n.t("chat.channel.dm_title.single_user", username: user1.username),
      )
    end

    context "when user is deleted" do
      it "returns a placeholder username" do
        direct_message = Fabricate(:direct_message, users: [user1, user2])
        user2.destroy!
        direct_message.reload

        expect(direct_message.chat_channel_title_for_user(chat_channel, user1)).to eq(
          I18n.t("chat.deleted_chat_username"),
        )
      end
    end

    context "when names are enabled" do
      before do
        SiteSetting.enable_names = true
        SiteSetting.display_name_on_posts = true
        SiteSetting.prioritize_username_in_ux = false
      end

      it "returns full name of user" do
        new_user = Fabricate.build(:user, username: "johndoe", name: "John Doe")
        direct_message = Fabricate(:direct_message, users: [user1, new_user])

        expect(direct_message.chat_channel_title_for_user(chat_channel, user1)).to eq(
          I18n.t("chat.channel.dm_title.single_user", username: "John Doe"),
        )
      end

      it "returns full names when chatting with multiple users" do
        user2.update!(name: "John Doe")
        user3 = Fabricate.build(:user, username: "chatdmbot", name: "Chat Bot")

        direct_message = Fabricate(:direct_message, users: [user1, user2, user3])

        expect(direct_message.chat_channel_title_for_user(chat_channel, user1)).to eq(
          I18n.t(
            "chat.channel.dm_title.multi_user",
            comma_separated_usernames:
              [user3.name, user2.name].map { |u| u }.join(I18n.t("word_connector.comma")),
          ),
        )
      end

      it "returns both full names and usernames when no name available" do
        new_user = Fabricate.build(:user, username: "johndoe", name: "John Doe")
        direct_message = Fabricate(:direct_message, users: [user1, new_user, user2])

        user2.update!(name: nil)
        expect(direct_message.chat_channel_title_for_user(chat_channel, user1)).to eq(
          I18n.t(
            "chat.channel.dm_title.multi_user",
            comma_separated_usernames: [user2.username, new_user.name].join(
              I18n.t("word_connector.comma"),
            ),
          ),
        )
      end
    end
  end
end
