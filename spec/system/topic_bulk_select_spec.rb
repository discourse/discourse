# frozen_string_literal: true

describe "Topic bulk select" do
  fab!(:topics) { Fabricate.times(10, :post).map(&:topic) }
  fab!(:admin)
  fab!(:user)

  let(:topic_list_header) { PageObjects::Components::TopicListHeader.new }
  let(:topic_list) { PageObjects::Components::TopicList.new }
  let(:topic_page) { PageObjects::Pages::Topic.new }
  let(:topic_bulk_actions_modal) { PageObjects::Modals::TopicBulkActions.new }
  let(:topic_view) { PageObjects::Components::TopicView.new }

  def open_bulk_actions_modal(topics_to_select = nil, action)
    topic_list_header.click_bulk_select_button

    if !topics_to_select
      topic_list.click_topic_checkbox(topics.last)
    else
      topics_to_select.each { |topic| topic_list.click_topic_checkbox(topic) }
    end

    topic_list_header.click_bulk_select_topics_dropdown
    topic_list_header.click_bulk_button(action)
    expect(topic_bulk_actions_modal).to be_open
  end

  context "when dismissing unread topics" do
    fab!(:topic) { Fabricate(:topic, user: admin) }
    fab!(:post1) { create_post(user: admin, topic: topic) }
    fab!(:post2) { create_post(topic: topic) }

    it "removes the topics from the list" do
      sign_in(admin)
      visit("/unread")

      topic_list_header.click_bulk_select_button
      expect(topic_list).to have_topic_checkbox(topic)

      topic_list.click_topic_checkbox(topic)

      topic_list_header.click_bulk_select_topics_dropdown
      topic_list_header.click_bulk_button("dismiss-unread")

      topic_bulk_actions_modal.click_dismiss_confirm

      expect(page).to have_text(I18n.t("js.topics.none.education.unread"))
    end

    it "turns off bulk select after dismissing" do
      other_topic = Fabricate(:topic, user: admin)
      create_post(user: admin, topic: other_topic)
      create_post(topic: other_topic)

      sign_in(admin)
      visit("/unread")

      topic_list_header.click_bulk_select_button
      topic_list.click_topic_checkbox(topic)

      topic_list_header.click_bulk_select_topics_dropdown
      topic_list_header.click_bulk_button("dismiss-unread")

      topic_bulk_actions_modal.click_dismiss_confirm

      expect(topic_list).to have_topic(other_topic)
      expect(topic_list).to have_no_topic_checkbox(other_topic)
    end
  end

  context "when dismissing new topics" do
    fab!(:topic) { Fabricate(:topic, user:) }
    fab!(:post1) { create_post(user:, topic:) }

    let(:topic_list_controls) { PageObjects::Components::TopicListControls.new }

    context "with the bulk actions dropdown" do
      it "removes the topics from the list" do
        sign_in(admin)
        visit("/new")

        topic_list_header.click_bulk_select_button
        expect(topic_list).to have_topic_checkbox(topic)

        topic_list.click_topic_checkbox(topic)

        topic_list_header.click_bulk_select_topics_dropdown
        topic_list_header.click_bulk_button("dismiss-new")

        expect(page).to have_text(I18n.t("js.topics.none.education.new"))
      end

      it "turns off bulk select after dismissing" do
        other_topic = Fabricate(:topic, user:)
        create_post(user:, topic: other_topic)

        sign_in(admin)
        visit("/new")

        topic_list_header.click_bulk_select_button
        topic_list.click_topic_checkbox(topic)

        topic_list_header.click_bulk_select_topics_dropdown
        topic_list_header.click_bulk_button("dismiss-new")

        expect(topic_list).to have_topic(other_topic)
        expect(topic_list).to have_no_topic_checkbox(other_topic)
      end
    end

    context "with the dismiss new button" do
      it "removes the topics from the list" do
        sign_in(admin)
        visit("/new")

        topic_list_header.click_bulk_select_button
        expect(topic_list).to have_topic_checkbox(topic)

        topic_list.click_topic_checkbox(topic)

        topic_list_controls.dismiss_new

        expect(page).to have_text(I18n.t("js.topics.none.education.new"))
      end

      it "turns off bulk select after dismissing" do
        other_topic = Fabricate(:topic, user:)
        create_post(user:, topic: other_topic)

        sign_in(admin)
        visit("/new")

        topic_list_header.click_bulk_select_button
        topic_list.click_topic_checkbox(topic)

        topic_list_controls.dismiss_new

        expect(topic_list).to have_topic(other_topic)
        expect(topic_list).to have_no_topic_checkbox(other_topic)
      end
    end
  end

  context "when managing tags" do
    fab!(:tag1, :tag)
    fab!(:tag2, :tag)
    fab!(:tag3, :tag)
    fab!(:topic) { Fabricate(:post).topic }
    fab!(:topic_2) { Fabricate(:post).topic }

    before { SiteSetting.tagging_enabled = true }

    def open_manage_tags_modal(topics_to_select)
      sign_in(admin)
      visit("/latest")

      open_bulk_actions_modal(topics_to_select, "manage-tags")
      PageObjects::Modals::ManageTags.new
    end

    context "when in mobile", mobile: true do
      it "is working" do
        # behavior is already tested on desktop, we simply ensure
        # the general workflow is working on mobile
        open_manage_tags_modal([topic, topic_2])
      end
    end

    it "removes all tags when the toggle is enabled" do
      topic.update!(tags: [tag1, tag2, tag3])
      topic_2.update!(tags: [tag1, tag2])

      modal = open_manage_tags_modal([topic, topic_2])
      modal.toggle_remove_all

      expect(modal).to have_remove_all_notice
      expect(modal).to have_no_remove_tag_selector

      modal.click_confirm

      expect(topic_list).to have_no_topic_tags(topic)
      expect(topic_list).to have_no_topic_tags(topic_2)
    end

    it "adds, removes, and replaces tags in a single submission" do
      tag4 = Fabricate(:tag)
      tag5 = Fabricate(:tag)
      topic.update!(tags: [tag1, tag2])
      topic_2.update!(tags: [tag1, tag3])

      modal = open_manage_tags_modal([topic, topic_2])
      expect(modal).to have_disabled_submit

      modal.select_replace_from(tag1.name)
      modal.select_replace_to(tag5.name)

      modal.add_tags(tag4.name)
      modal.remove_tags(tag2.name)

      modal.click_confirm

      expect(topic_list).to have_topic_tags(topic, tags: [tag4, tag5])
      expect(topic_list).to have_topic_tags(topic_2, tags: [tag3, tag4, tag5])
    end

    context "when selecting topics that are all in the same category" do
      fab!(:category)

      before do
        topic.update!(category_id: category.id)
        topic_2.update!(category_id: category.id)
      end

      it "limits tag search to restricted tags when category does not allow global tags" do
        restricted_tag_group = Fabricate(:tag_group)
        restricted_tag = Fabricate(:tag)
        TagGroupMembership.create!(tag: restricted_tag, tag_group: restricted_tag_group)
        CategoryTagGroup.create!(category: category, tag_group: restricted_tag_group)

        modal = open_manage_tags_modal([topic, topic_2])

        modal.add_tag_selector.expand

        expect(modal.add_tag_selector.option_names).to contain_exactly(restricted_tag.name)
      end

      it "allows for searching restricted tags for that category and other tags too if the category allows it" do
        restricted_tag_group = Fabricate(:tag_group)
        restricted_tag = Fabricate(:tag)
        TagGroupMembership.create!(tag: restricted_tag, tag_group: restricted_tag_group)
        CategoryTagGroup.create!(category: category, tag_group: restricted_tag_group)
        category.update!(allow_global_tags: true)

        modal = open_manage_tags_modal([topic, topic_2])

        modal.add_tags(restricted_tag.name, tag1.name)

        modal.click_confirm

        expect(topic_list).to have_topic_tags(topic, tags: [restricted_tag, tag1])
        expect(topic_list).to have_topic_tags(topic_2, tags: [restricted_tag, tag1])
      end
    end
  end

  context "when closing" do
    it "closes multiple topics" do
      sign_in(admin)
      visit("/latest")

      # Click bulk select button
      topic_list_header.click_bulk_select_button
      expect(topic_list).to have_topic_checkbox(topics.first)

      # Select Topics
      topic_list.click_topic_checkbox(topics.first)
      topic_list.click_topic_checkbox(topics.second)

      # Has Dropdown
      expect(topic_list_header).to have_bulk_select_topics_dropdown
      topic_list_header.click_bulk_select_topics_dropdown

      # Clicking the close button opens up the modal
      topic_list_header.click_bulk_button("close-topics")
      expect(topic_bulk_actions_modal).to be_open

      # Closes the selected topics
      topic_bulk_actions_modal.click_bulk_topics_confirm
      expect(topic_list).to have_closed_status(topics.first)
      expect(topic_list).to have_closed_status(topics.second)
    end

    it "closes single topic" do
      # Watch the topic as a user
      sign_in(user)
      visit("/latest")
      topic = topics.third
      visit("/t/#{topic.slug}/#{topic.id}")
      topic_page.watch_topic
      expect(topic_page).to have_read_post(1)

      # Bulk close the topic as an admin
      using_session(:admin) do
        sign_in(admin)
        visit("/latest")
        topic_list_header.click_bulk_select_button
        topic_list.click_topic_checkbox(topics.third)
        topic_list_header.click_bulk_select_topics_dropdown
        topic_list_header.click_bulk_button("close-topics")
        topic_bulk_actions_modal.click_notify
        topic_bulk_actions_modal.click_bulk_topics_confirm
        expect(topic_list).to have_closed_status(topics.third)
      end

      # Check that the user did receive a new post notification badge
      visit("/latest")
      expect(topic_list).to have_unread_badge(topics.third)
    end

    it "closes topics silently" do
      # Watch the topic as a user
      sign_in(user)
      topic = topics.first
      visit("/t/#{topic.slug}/#{topic.id}")
      expect(topic_view).to have_read_post(topic.posts.first)
      topic_page.watch_topic

      # Bulk close the topic as an admin
      using_session(:admin) do
        sign_in(admin)
        visit("/latest")
        topic_list_header.click_bulk_select_button
        topic_list.click_topic_checkbox(topics.first)
        topic_list_header.click_bulk_select_topics_dropdown
        topic_list_header.click_bulk_button("close-topics")
        topic_bulk_actions_modal.click_bulk_topics_confirm
        expect(topic_list).to have_closed_status(topics.first)
      end

      # Check that the user didn't receive a new post notification badge
      sign_in(user)
      visit("/latest")
      expect(topic_list).to have_no_unread_badge(topics.first)
    end

    it "closes topics with message" do
      # Bulk close the topic with a message
      sign_in(admin)
      visit("/latest")
      topic = topics.first
      topic_list_header.click_bulk_select_button
      topic_list.click_topic_checkbox(topics.first)
      topic_list_header.click_bulk_select_topics_dropdown
      topic_list_header.click_bulk_button("close-topics")

      # Fill in message
      topic_bulk_actions_modal.fill_in_close_note("None of these are useful")
      topic_bulk_actions_modal.click_bulk_topics_confirm
      expect(topic_list).to have_closed_status(topics.first)

      # Check that the topic now has the message
      visit("/t/#{topic.slug}/#{topic.id}")
      expect(topic_page).to have_content("None of these are useful")
    end

    it "works with keyboard shortcuts" do
      sign_in(admin)
      visit("/latest")

      send_keys([:shift, "b"])
      send_keys("j")
      send_keys("x") # toggle select
      expect(topic_list).to have_checkbox_selected_on_row(1)

      send_keys("x") # toggle deselect
      expect(topic_list).to have_no_checkbox_selected_on_row(1)

      # watch topic and add a reply so we have something in /unread
      topic = topics.first
      visit("/t/#{topic.slug}/#{topic.id}")
      topic_page.watch_topic
      expect(topic_page).to have_read_post(1)
      Fabricate(:post, topic: topic)

      visit("/unread")
      expect(topic_list).to have_topics

      send_keys([:shift, "b"])
      send_keys("j")
      send_keys("x")
      send_keys([:shift, "d"])

      click_button("dismiss-read-confirm")

      expect(topic_list).to have_no_topics
    end
  end

  context "when working with private messages" do
    fab!(:private_message_1) do
      Fabricate(:private_message_topic, user: admin, recipient: user, participant_count: 2)
    end
    fab!(:private_message_post_1) { Fabricate(:post, topic: private_message_1, user: admin) }
    fab!(:private_message_post_2) { Fabricate(:post, topic: private_message_1, user: user) }
    fab!(:group)
    fab!(:group_private_message) do
      Fabricate(:group_private_message_topic, user: admin, recipient_group: group)
    end

    before do
      TopicUser.change(
        admin.id,
        private_message_1,
        notification_level: TopicUser.notification_levels[:tracking],
      )
      TopicUser.update_last_read(admin, private_message_1.id, 1, 1, 1)
      GroupUser.create!(user: admin, group: group)
    end

    it "allows moving private messages to the Archive" do
      sign_in(admin)
      visit("/u/#{admin.username}/messages")
      expect(page).to have_content(private_message_1.title)
      open_bulk_actions_modal([private_message_1], "archive-messages")
      topic_bulk_actions_modal.click_bulk_topics_confirm
      expect(page).to have_content(I18n.t("js.topics.bulk.completed"))
      visit("/u/#{admin.username}/messages/archive")
      expect(page).to have_content(private_message_1.title)
      expect(UserArchivedMessage.exists?(user_id: admin.id, topic_id: private_message_1.id)).to eq(
        true,
      )
    end

    it "allows moving private messages to the Inbox" do
      UserArchivedMessage.create!(user: admin, topic: private_message_1)
      sign_in(admin)
      visit("/u/#{admin.username}/messages/archive")
      expect(page).to have_content(private_message_1.title)
      open_bulk_actions_modal([private_message_1], "move-messages-to-inbox")
      topic_bulk_actions_modal.click_bulk_topics_confirm
      expect(page).to have_content(I18n.t("js.topics.bulk.completed"))
      visit("/u/#{admin.username}/messages")
      expect(page).to have_content(private_message_1.title)
    end

    it "allows moving group private messages to the scoped group Archive" do
      sign_in(admin)
      visit("/u/#{admin.username}/messages/group/#{group.name}")
      expect(page).to have_content(group_private_message.title)
      open_bulk_actions_modal([group_private_message], "archive-messages")
      topic_bulk_actions_modal.click_bulk_topics_confirm
      expect(page).to have_content(I18n.t("js.topics.bulk.completed"))
      visit("/u/#{admin.username}/messages/group/#{group.name}/archive")
      expect(page).to have_content(group_private_message.title)
    end

    it "allows archiving group private messages from the group inbox page" do
      sign_in(admin)
      visit("/g/#{group.name}/messages/inbox")
      expect(page).to have_content(group_private_message.title)
      open_bulk_actions_modal([group_private_message], "archive-messages")
      topic_bulk_actions_modal.click_bulk_topics_confirm
      expect(page).to have_content(I18n.t("js.topics.bulk.completed"))
      visit("/g/#{group.name}/messages/archive")
      expect(page).to have_content(group_private_message.title)
    end

    it "allows moving group private messages to the scoped group Inbox" do
      GroupArchivedMessage.create!(group: group, topic: group_private_message)
      sign_in(admin)
      visit("/u/#{admin.username}/messages/group/#{group.name}/archive")
      expect(page).to have_content(group_private_message.title)
      open_bulk_actions_modal([group_private_message], "move-messages-to-inbox")
      topic_bulk_actions_modal.click_bulk_topics_confirm
      expect(page).to have_content(I18n.t("js.topics.bulk.completed"))
      visit("/u/#{admin.username}/messages/group/#{group.name}")
      expect(page).to have_content(group_private_message.title)
    end

    context "when in mobile" do
      it "is working", mobile: true do
        # behavior is already tested on desktop, we simply ensure
        # the general workflow is working on mobile
        sign_in(admin)
        visit("/u/#{admin.username}/messages")
        open_bulk_actions_modal([private_message_1], "archive-messages")
      end
    end
  end

  context "when clicking on the row" do
    it "selects it" do
      sign_in(admin)
      visit("/latest")

      topic_list_header.click_bulk_select_button
      topic_list.click_topic_title(topics.last)

      expect(topic_list).to have_checkbox_selected_on_row(1)
    end

    it "opens topic in new window when pressing meta+Enter" do
      sign_in(admin)
      visit("/latest")

      topic_list_header.click_bulk_select_button

      new_window =
        window_opened_by do
          find(".topic-list-item[data-topic-id='#{topics.last.id}'] a.raw-topic-link").send_keys(
            %i[meta return],
          )
        end

      within_window(new_window) { expect(topic_page).to have_topic_title(topics.last.title) }
    end
  end

  context "when changing topic notification levels" do
    it "allows changing notification levels for selected topics" do
      sign_in(admin)
      visit("/latest")

      # Click bulk select button
      topic_list_header.click_bulk_select_button
      expect(topic_list).to have_topic_checkbox(topics.first)

      # Select Topics
      topic_list.click_topic_checkbox(topics.first)
      topic_list.click_topic_checkbox(topics.second)

      # Has Dropdown
      expect(topic_list_header).to have_bulk_select_topics_dropdown
      topic_list_header.click_bulk_select_topics_dropdown

      topic_list_header.click_bulk_button("update-notifications")
      expect(topic_bulk_actions_modal).to be_open

      # By default, the confirm button is disabled
      expect(page).to have_css("#bulk-topics-confirm:disabled")

      topic_bulk_actions_modal.select_notification_level(NotificationLevels.all[:muted])
      topic_bulk_actions_modal.click_bulk_topics_confirm

      expect(topic_list).to have_no_topic(topics.first)
      expect(topic_list).to have_no_topic(topics.second)
    end
  end

  context "when changing category" do
    fab!(:destination_category, :category)
    fab!(:restricted_tag, :tag)

    before do
      SiteSetting.tagging_enabled = true
      topics.first.update!(tags: [restricted_tag])
      topics.first.category.update!(tags: [restricted_tag])
    end

    it "shows errors in the modal when some topics cannot be moved due to tag restrictions" do
      original_category = topics.first.category
      sign_in(admin)
      visit("/latest")

      open_bulk_actions_modal([topics.first], "update-category")

      topic_bulk_actions_modal.category_selector.expand
      topic_bulk_actions_modal.category_selector.select_row_by_value(destination_category.id)
      topic_bulk_actions_modal.click_bulk_topics_confirm

      expect(topic_bulk_actions_modal).to have_errors("could not be updated")

      expect(topics.first.reload.category).to eq(original_category)
    end
  end
end
