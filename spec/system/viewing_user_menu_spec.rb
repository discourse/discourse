# frozen_string_literal: true

RSpec.describe "Viewing User Menu", system: true do
  fab!(:user) { Fabricate(:user) }

  let(:user_menu) { PageObjects::Components::UserMenu.new }

  describe "when viewing replies notifications tab" do
    fab!(:topic) { Fabricate(:topic) }

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
  end
end
