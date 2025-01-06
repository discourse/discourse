# frozen_string_literal: true

RSpec.describe "Viewing User Menu", system: true do
  fab!(:user)

  let(:user_menu) { PageObjects::Components::UserMenu.new }

  describe "with notification limit set via plugin api" do
    it "only displays as many notifications as the limit" do
      sign_in(user)

      visit("/latest")

      3.times { Fabricate(:notification, user: user) }
      page.execute_script <<~JS
        require("discourse/lib/plugin-api").withPluginApi("1.22.0", (api) => {
          api.setUserMenuNotificationsLimit(2);
        })
      JS

      user_menu.open

      expect(user_menu).to have_notification_count_of(2)
    end
  end

  describe "when viewing replies notifications tab" do
    fab!(:topic)

    it "should display group mentioned notifications in the tab" do
      Jobs.run_immediately!

      mentionable_group = Fabricate(:group, mentionable_level: Group::ALIAS_LEVELS[:everyone])
      user_in_mentionable_group = Fabricate(:user).tap { |user| mentionable_group.add(user) }

      _post_with_group_mention =
        PostCreator.create!(user, topic_id: topic.id, raw: "Hello @#{mentionable_group.name}")

      sign_in(user_in_mentionable_group)

      visit("/latest")

      user_menu.open

      expect(user_menu).to have_right_replies_button_count(1)

      user_menu.click_replies_notifications_tab

      expect(user_menu).to have_group_mentioned_notification(topic, user, mentionable_group)
    end

    context "with SiteSetting.prioritize_username_in_ux=false" do
      before do
        SiteSetting.prioritize_username_in_ux = false
      end

      it "should display user full name in mention notifications" do
        Jobs.run_immediately!

        user = Fabricate(:user)
        user2 = Fabricate(:user, name: "John Doe")
        PostCreator.create!(user, topic_id: topic.id, raw: "Hello @#{user2.username}")

        sign_in(user2)

        visit("/latest")

        user_menu.open

        expect(user_menu).to have_right_replies_button_count(1)

        user_menu.click_replies_notifications_tab

        expect(user_menu).to have_user_full_name_mentioned_notification(topic, user)
      end

      it "should display user full name in message notification" do
        Jobs.run_immediately!

        user = Fabricate(:moderator)
        user2 = Fabricate(:user, name: "John Doe")
        post = PostCreator.create!(
          user,
          title: "message",
          raw: "private message",
          archetype: Archetype.private_message,
          target_usernames: [user2.username]
        )

        sign_in(user2)

        visit("/latest")

        user_menu.open

        expect(user_menu).to have_user_full_name_messaged_notification(post, user)
      end

      it "should display user full name in bookmarks" do
        Jobs.run_immediately!

        user = Fabricate(:user)
        user2 = Fabricate(:user, name: "John Doe")
        puts SiteSetting.prioritize_username_in_ux ? "true" : "false"
        PostCreator.create!(user, topic_id: topic.id, raw: "Hello @#{user2.username}")
        Bookmark.create!(user: user2, topic: topic)
        sign_in(user2)

        visit("/latest")

        user_menu.open


        user_menu.click_bookmarks_tab

        expect(user_menu).to have_user_full_name_bookmarked_notification(topic, user)
      end

    end

    context "with SiteSetting.prioritize_username_in_ux=true" do
      before do
        SiteSetting.prioritize_username_in_ux = true
      end

      it "should display only username in mention notifications" do
        Jobs.run_immediately!

        SiteSetting.prioritize_username_in_ux = true

        user = Fabricate(:user)
        user2 = Fabricate(:user, name: "John Doe")

        PostCreator.create!(user, topic_id: topic.id, raw: "Hello @#{user2.username}")

        sign_in(user2)

        visit("/latest")

        user_menu.open

        expect(user_menu).to have_right_replies_button_count(1)

        user_menu.click_replies_notifications_tab

        expect(user_menu).to have_user_username_mentioned_notification(topic, user)
      end

    end
  end
end


