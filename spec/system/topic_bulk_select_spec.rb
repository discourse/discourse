# frozen_string_literal: true

describe "Topic bulk select" do
  fab!(:topics) { Fabricate.times(10, :post).map(&:topic) }
  fab!(:admin)
  fab!(:user)

  let(:topic_list_header) { PageObjects::Components::TopicListHeader.new }
  let(:topic_list) { PageObjects::Components::TopicList.new }
  let(:topic_page) { PageObjects::Pages::Topic.new }
  let(:topic_bulk_actions_modal) { PageObjects::Modals::TopicBulkActions.new }

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

  context "when dismissing new replies" do
    fab!(:topic) { Fabricate(:topic, user: admin) }
    fab!(:post1) { create_post(user: admin, topic: topic) }
    fab!(:post2) { create_post(topic: topic) }

    before { SiteSetting.enable_unified_new = true }

    it "removes the topics from the list" do
      sign_in(admin)
      browser_page.goto("/new?subset=replies").tap { SystemBrowserBootstrap.wait_for(browser_page) }

      topic_list_header.click_bulk_select_button
      expect(topic_list).to have_topic_checkbox(topic)

      topic_list.click_topic_checkbox(topic)

      topic_list_header.click_bulk_select_topics_dropdown
      topic_list_header.click_bulk_button("dismiss-new")

      expect(topic_list).to have_no_topics
    end

    it "turns off bulk select after dismissing" do
      other_topic = Fabricate(:topic, user: admin)
      create_post(user: admin, topic: other_topic)
      create_post(topic: other_topic)

      sign_in(admin)
      browser_page.goto("/new?subset=replies").tap { SystemBrowserBootstrap.wait_for(browser_page) }

      topic_list_header.click_bulk_select_button
      topic_list.click_topic_checkbox(topic)

      topic_list_header.click_bulk_select_topics_dropdown
      topic_list_header.click_bulk_button("dismiss-new")

      expect(topic_list).to have_topic(other_topic)
      expect(topic_list).to have_no_topic_checkbox(other_topic)
    end
  end

  context "when dismissing new topics" do
    fab!(:topic) { Fabricate(:topic, user:) }
    fab!(:post1) { create_post(user:, topic:) }

    let(:topic_list_controls) { PageObjects::Components::TopicListControls.new }

    before { SiteSetting.enable_unified_new = true }

    context "with the bulk actions dropdown" do
      it "removes the topics from the list" do
        sign_in(admin)
        browser_page.goto("/new").tap { SystemBrowserBootstrap.wait_for(browser_page) }

        topic_list_header.click_bulk_select_button
        expect(topic_list).to have_topic_checkbox(topic)

        topic_list.click_topic_checkbox(topic)

        topic_list_header.click_bulk_select_topics_dropdown
        topic_list_header.click_bulk_button("dismiss-new")

        expect(browser_content).to PlaywrightMatchers.contain_text(
          browser_text_pattern(I18n.t("js.topics.none.education.new")),
          useInnerText: true,
        )
      end

      it "turns off bulk select after dismissing" do
        other_topic = Fabricate(:topic, user:)
        create_post(user:, topic: other_topic)

        sign_in(admin)
        browser_page.goto("/new").tap { SystemBrowserBootstrap.wait_for(browser_page) }

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
        browser_page.goto("/new").tap { SystemBrowserBootstrap.wait_for(browser_page) }

        topic_list_header.click_bulk_select_button
        expect(topic_list).to have_topic_checkbox(topic)

        topic_list.click_topic_checkbox(topic)

        topic_list_controls.dismiss_new

        expect(browser_content).to PlaywrightMatchers.contain_text(
          browser_text_pattern(I18n.t("js.topics.none.education.new")),
          useInnerText: true,
        )
      end

      it "turns off bulk select after dismissing" do
        other_topic = Fabricate(:topic, user:)
        create_post(user:, topic: other_topic)

        sign_in(admin)
        browser_page.goto("/new").tap { SystemBrowserBootstrap.wait_for(browser_page) }

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
      browser_page.goto("/latest").tap { SystemBrowserBootstrap.wait_for(browser_page) }

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

      it "can remove and replace-away a restricted tag" do
        restricted_tag_group = Fabricate(:tag_group)
        restricted_to_remove = Fabricate(:tag)
        restricted_to_replace = Fabricate(:tag)
        [restricted_to_remove, restricted_to_replace].each do |t|
          TagGroupMembership.create!(tag: t, tag_group: restricted_tag_group)
        end
        CategoryTagGroup.create!(category: category, tag_group: restricted_tag_group)
        category.update!(allow_global_tags: true)
        topic.update!(tags: [restricted_to_remove, restricted_to_replace])

        modal = open_manage_tags_modal([topic, topic_2])

        modal.remove_tags(restricted_to_remove.name)
        modal.select_replace_from(restricted_to_replace.name)
        modal.select_replace_to(tag1.name)

        modal.click_confirm

        expect(topic_list).to have_topic_tags(topic, tags: [tag1])
      end
    end

    context "when selecting topics across multiple categories" do
      fab!(:category_a, :category)
      fab!(:category_b, :category)
      fab!(:restricted_tag_group, :tag_group)
      fab!(:restricted_tag, :tag)

      before do
        topic.update!(category_id: category_a.id)
        topic_2.update!(category_id: category_b.id)
        TagGroupMembership.create!(tag: restricted_tag, tag_group: restricted_tag_group)
      end

      it "lets a restricted tag be added when every selected category allows it" do
        CategoryTagGroup.create!(category: category_a, tag_group: restricted_tag_group)
        CategoryTagGroup.create!(category: category_b, tag_group: restricted_tag_group)

        modal = open_manage_tags_modal([topic, topic_2])
        modal.add_tags(restricted_tag.name)
        modal.click_confirm

        expect(topic_list).to have_topic_tags(topic, tags: [restricted_tag])
        expect(topic_list).to have_topic_tags(topic_2, tags: [restricted_tag])
      end

      it "reports an error for topics whose category forbids the tag" do
        CategoryTagGroup.create!(category: category_a, tag_group: restricted_tag_group)

        modal = open_manage_tags_modal([topic, topic_2])
        modal.add_tags(restricted_tag.name)
        modal.click_confirm

        expect(topic_bulk_actions_modal).to have_errors
        expect(
          browser_root.locator(".topic-bulk-actions-modal__errors .badge-category").filter(
            visible: true,
          ),
        ).to PlaywrightMatchers.contain_text(
          [browser_text_pattern(category_b.name)],
          useInnerText: true,
        )
        expect(
          browser_root.locator(".topic-bulk-actions-modal__errors .discourse-tag").filter(
            visible: true,
          ),
        ).to PlaywrightMatchers.contain_text(
          [browser_text_pattern(restricted_tag.name)],
          useInnerText: true,
        )
        expect(
          browser_root.locator("#bulk-topics-close").filter(visible: true),
        ).not_to PlaywrightMatchers.have_count(0)
        expect(
          browser_root.locator("#bulk-topics-confirm").filter(visible: true),
        ).to PlaywrightMatchers.have_count(0)
        expect(topic.reload.tags).to include(restricted_tag)
        expect(topic_2.reload.tags).not_to include(restricted_tag)
      end
    end
  end

  context "when closing" do
    it "closes multiple topics" do
      sign_in(admin)
      browser_page.goto("/latest").tap { SystemBrowserBootstrap.wait_for(browser_page) }

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
      browser_page.goto("/latest").tap { SystemBrowserBootstrap.wait_for(browser_page) }
      topic = topics.third
      browser_page
        .goto("/t/#{topic.slug}/#{topic.id}")
        .tap { SystemBrowserBootstrap.wait_for(browser_page) }
      topic_page.watch_topic
      expect(topic_page).to have_read_post(1)

      # Bulk close the topic as an admin
      using_browser_session(:admin) do
        sign_in(admin)
        browser_page.goto("/latest").tap { SystemBrowserBootstrap.wait_for(browser_page) }
        topic_list_header.click_bulk_select_button
        topic_list.click_topic_checkbox(topics.third)
        topic_list_header.click_bulk_select_topics_dropdown
        topic_list_header.click_bulk_button("close-topics")
        topic_bulk_actions_modal.click_bulk_topics_confirm
        expect(topic_list).to have_closed_status(topics.third)
      end

      # The bulk close posts a small action, which no longer marks the topic
      # unread, so the watching user does not get a new post notification badge.
      browser_page.goto("/latest").tap { SystemBrowserBootstrap.wait_for(browser_page) }
      expect(topic_list).to have_no_unread_badge(topics.third)
    end

    it "closes topics with message" do
      # Bulk close the topic with a message
      sign_in(admin)
      browser_page.goto("/latest").tap { SystemBrowserBootstrap.wait_for(browser_page) }
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
      browser_page
        .goto("/t/#{topic.slug}/#{topic.id}")
        .tap { SystemBrowserBootstrap.wait_for(browser_page) }
      expect(topic_page).to have_displayed_content("None of these are useful")
    end

    it "works with keyboard shortcuts" do
      SiteSetting.enable_unified_new = true

      sign_in(admin)
      browser_page.goto("/latest").tap { SystemBrowserBootstrap.wait_for(browser_page) }

      expect(
        browser_root.locator("#site-logo").filter(visible: true),
      ).not_to PlaywrightMatchers.have_count(0)

      browser_page.keyboard.press(%w[Shift b].join("+"))
      expect(topic_list).to have_bulk_select_enabled
      browser_page.keyboard.type("j")
      browser_page.keyboard.type("x") # toggle select
      expect(topic_list).to have_checkbox_selected_on_row(1)

      browser_page.keyboard.type("x") # toggle deselect
      expect(topic_list).to have_no_checkbox_selected_on_row(1)

      # watch topic and add a reply so we have something in /new?subset=replies
      topic = topics.first
      browser_page
        .goto("/t/#{topic.slug}/#{topic.id}")
        .tap { SystemBrowserBootstrap.wait_for(browser_page) }
      topic_page.watch_topic
      expect(topic_page).to have_read_post(1)
      Fabricate(:post, topic: topic)

      browser_page.goto("/new?subset=replies").tap { SystemBrowserBootstrap.wait_for(browser_page) }
      expect(topic_list).to have_topics

      browser_page.keyboard.press(%w[Shift b].join("+"))
      expect(topic_list).to have_bulk_select_enabled
      browser_page.keyboard.type("j")
      browser_page.keyboard.type("x")
      browser_page.keyboard.press(%w[Shift d].join("+"))

      expect(topic_list).to have_no_topics
    end
  end

  context "when deleting" do
    it "removes the deleted topics from the list" do
      sign_in(admin)
      browser_page.goto("/latest").tap { SystemBrowserBootstrap.wait_for(browser_page) }

      open_bulk_actions_modal([topics.first, topics.second], "delete-topics")
      topic_bulk_actions_modal.click_bulk_topics_confirm

      expect(topic_list).to have_no_topic(topics.first)
      expect(topic_list).to have_no_topic(topics.second)
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
      browser_page
        .goto("/u/#{admin.username}/messages")
        .tap { SystemBrowserBootstrap.wait_for(browser_page) }
      expect(browser_content).to PlaywrightMatchers.contain_text(
        browser_text_pattern(private_message_1.title),
        useInnerText: true,
      )
      open_bulk_actions_modal([private_message_1], "archive-messages")
      topic_bulk_actions_modal.click_bulk_topics_confirm
      expect(browser_content).to PlaywrightMatchers.contain_text(
        browser_text_pattern(I18n.t("js.topics.bulk.completed")),
        useInnerText: true,
      )
      browser_page
        .goto("/u/#{admin.username}/messages/archive")
        .tap { SystemBrowserBootstrap.wait_for(browser_page) }
      expect(browser_content).to PlaywrightMatchers.contain_text(
        browser_text_pattern(private_message_1.title),
        useInnerText: true,
      )
      expect(UserArchivedMessage.exists?(user_id: admin.id, topic_id: private_message_1.id)).to eq(
        true,
      )
    end

    it "allows moving private messages to the Inbox" do
      UserArchivedMessage.create!(user: admin, topic: private_message_1)
      sign_in(admin)
      browser_page
        .goto("/u/#{admin.username}/messages/archive")
        .tap { SystemBrowserBootstrap.wait_for(browser_page) }
      expect(browser_content).to PlaywrightMatchers.contain_text(
        browser_text_pattern(private_message_1.title),
        useInnerText: true,
      )
      open_bulk_actions_modal([private_message_1], "move-messages-to-inbox")
      topic_bulk_actions_modal.click_bulk_topics_confirm
      expect(browser_content).to PlaywrightMatchers.contain_text(
        browser_text_pattern(I18n.t("js.topics.bulk.completed")),
        useInnerText: true,
      )
      browser_page
        .goto("/u/#{admin.username}/messages")
        .tap { SystemBrowserBootstrap.wait_for(browser_page) }
      expect(browser_content).to PlaywrightMatchers.contain_text(
        browser_text_pattern(private_message_1.title),
        useInnerText: true,
      )
    end

    it "allows moving group private messages to the scoped group Archive" do
      sign_in(admin)
      browser_page
        .goto("/u/#{admin.username}/messages/group/#{group.name}")
        .tap { SystemBrowserBootstrap.wait_for(browser_page) }
      expect(browser_content).to PlaywrightMatchers.contain_text(
        browser_text_pattern(group_private_message.title),
        useInnerText: true,
      )
      open_bulk_actions_modal([group_private_message], "archive-messages")
      topic_bulk_actions_modal.click_bulk_topics_confirm
      expect(browser_content).to PlaywrightMatchers.contain_text(
        browser_text_pattern(I18n.t("js.topics.bulk.completed")),
        useInnerText: true,
      )
      browser_page
        .goto("/u/#{admin.username}/messages/group/#{group.name}/archive")
        .tap { SystemBrowserBootstrap.wait_for(browser_page) }
      expect(browser_content).to PlaywrightMatchers.contain_text(
        browser_text_pattern(group_private_message.title),
        useInnerText: true,
      )
    end

    it "removes archived group messages from the current inbox after infinite-scroll pagination" do
      # Regression test: when the paginated topic list is cached in the
      # session, refreshing the route after a bulk archive reused the
      # stale cached list and left archived messages visible until the
      # user manually reloaded.
      other_group_messages =
        Array.new(2) do
          Fabricate(:group_private_message_topic, user: admin, recipient_group: group)
        end
      all_group_messages = [group_private_message, *other_group_messages]

      stub_const(TopicQuery, "DEFAULT_PER_PAGE_COUNT", 2) do
        sign_in(admin)
        browser_page
          .goto("/u/#{admin.username}/messages/group/#{group.name}")
          .tap { SystemBrowserBootstrap.wait_for(browser_page) }

        expect(topic_list).to have_topics(count: 2)
        browser_page.evaluate(
          "function(arguments) { document.querySelector('.paginated-topics-list .load-more-sentinel').scrollIntoView() }",
          arg: [],
        )
        expect(topic_list).to have_topics(count: all_group_messages.size)

        topic_list_header.click_bulk_select_button
        all_group_messages.each { |topic| topic_list.click_topic_checkbox(topic) }

        topic_list_header.click_bulk_select_topics_dropdown
        topic_list_header.click_bulk_button("archive-messages")
        expect(topic_bulk_actions_modal).to be_open
        topic_bulk_actions_modal.click_bulk_topics_confirm

        expect(browser_content).to PlaywrightMatchers.contain_text(
          browser_text_pattern(I18n.t("js.topics.bulk.completed")),
          useInnerText: true,
        )
        all_group_messages.each do |topic|
          expect(topic_list).to have_no_topic(topic)
          expect(GroupArchivedMessage.exists?(group_id: group.id, topic_id: topic.id)).to eq(true)
        end
      end
    end

    it "allows archiving group private messages from the group inbox page" do
      sign_in(admin)
      browser_page
        .goto("/g/#{group.name}/messages/inbox")
        .tap { SystemBrowserBootstrap.wait_for(browser_page) }
      expect(browser_content).to PlaywrightMatchers.contain_text(
        browser_text_pattern(group_private_message.title),
        useInnerText: true,
      )
      open_bulk_actions_modal([group_private_message], "archive-messages")
      topic_bulk_actions_modal.click_bulk_topics_confirm
      expect(browser_content).to PlaywrightMatchers.contain_text(
        browser_text_pattern(I18n.t("js.topics.bulk.completed")),
        useInnerText: true,
      )
      browser_page
        .goto("/g/#{group.name}/messages/archive")
        .tap { SystemBrowserBootstrap.wait_for(browser_page) }
      expect(browser_content).to PlaywrightMatchers.contain_text(
        browser_text_pattern(group_private_message.title),
        useInnerText: true,
      )
    end

    it "allows moving group private messages to the scoped group Inbox" do
      GroupArchivedMessage.create!(group: group, topic: group_private_message)
      sign_in(admin)
      browser_page
        .goto("/u/#{admin.username}/messages/group/#{group.name}/archive")
        .tap { SystemBrowserBootstrap.wait_for(browser_page) }
      expect(browser_content).to PlaywrightMatchers.contain_text(
        browser_text_pattern(group_private_message.title),
        useInnerText: true,
      )
      open_bulk_actions_modal([group_private_message], "move-messages-to-inbox")
      topic_bulk_actions_modal.click_bulk_topics_confirm
      expect(browser_content).to PlaywrightMatchers.contain_text(
        browser_text_pattern(I18n.t("js.topics.bulk.completed")),
        useInnerText: true,
      )
      browser_page
        .goto("/u/#{admin.username}/messages/group/#{group.name}")
        .tap { SystemBrowserBootstrap.wait_for(browser_page) }
      expect(browser_content).to PlaywrightMatchers.contain_text(
        browser_text_pattern(group_private_message.title),
        useInnerText: true,
      )
    end

    context "when in mobile" do
      it "is working", mobile: true do
        # behavior is already tested on desktop, we simply ensure
        # the general workflow is working on mobile
        sign_in(admin)
        browser_page
          .goto("/u/#{admin.username}/messages")
          .tap { SystemBrowserBootstrap.wait_for(browser_page) }
        open_bulk_actions_modal([private_message_1], "archive-messages")
      end
    end
  end

  context "when clicking on the row" do
    it "selects it" do
      sign_in(admin)
      browser_page.goto("/latest").tap { SystemBrowserBootstrap.wait_for(browser_page) }

      topic_list_header.click_bulk_select_button
      topic_list.click_topic_title(topics.last)

      expect(topic_list).to have_checkbox_selected_on_row(1)
    end

    it "opens topic in new window when pressing meta+Enter" do
      sign_in(admin)
      browser_page.goto("/latest").tap { SystemBrowserBootstrap.wait_for(browser_page) }

      topic_list_header.click_bulk_select_button

      new_window =
        browser_page.expect_popup do
          browser_root
            .locator(".topic-list-item[data-topic-id='#{topics.last.id}'] a.raw-topic-link")
            .filter(visible: true)
            .press(%w[Meta Enter].join("+"))
        end

      using_browser_page(new_window) { expect(topic_page).to have_topic_title(topics.last.title) }
    end
  end

  context "when changing topic notification levels" do
    it "allows changing notification levels for selected topics" do
      sign_in(admin)
      browser_page.goto("/latest").tap { SystemBrowserBootstrap.wait_for(browser_page) }

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
      expect(
        browser_root.locator("#bulk-topics-confirm:disabled").filter(visible: true),
      ).not_to PlaywrightMatchers.have_count(0)

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
      sign_in(Fabricate(:moderator))
      browser_page.goto("/latest").tap { SystemBrowserBootstrap.wait_for(browser_page) }

      open_bulk_actions_modal([topics.first], "update-category")

      topic_bulk_actions_modal.category_selector.expand
      topic_bulk_actions_modal.category_selector.select_row_by_value(destination_category.id)
      topic_bulk_actions_modal.click_bulk_topics_confirm

      expect(topic_bulk_actions_modal).to have_errors("could not be updated")

      expect(topics.first.reload.category).to eq(original_category)
    end
  end
end
