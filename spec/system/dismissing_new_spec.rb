# frozen_string_literal: true

RSpec.describe "Dismissing New", type: :system do
  fab!(:user) { Fabricate(:user, refresh_auto_groups: true) }

  let(:discovery) { PageObjects::Pages::Discovery.new }
  let(:topic_list_controls) { PageObjects::Components::TopicListControls.new }
  let(:topic_list) { PageObjects::Components::TopicList.new }
  let(:dismiss_new_modal) { PageObjects::Modals::DismissNew.new }
  let(:topic_view) { PageObjects::Components::TopicView.new }

  describe "when a user has an unread post" do
    fab!(:topic) { Fabricate(:topic, user: user) }
    fab!(:post1) { create_post(user: user, topic: topic) }
    fab!(:post2) { create_post(topic: topic) }

    it "should untrack topics across sessions after the user dismisses it" do
      sign_in(user)

      visit("/unread")

      using_session(:tab_1) do
        sign_in(user)

        visit("/t/#{topic.id}")

        expect(topic_view).to have_tracking_status("tracking")
      end

      topic_list_controls.dismiss_unread(untrack: true)

      using_session(:tab_1) do
        try_until_success(reason: "relies on MessageBus updates") do
          expect(topic_view).to have_tracking_status("regular")
        end
      end
    end

    context "when dismissing new on a category's topic list" do
      fab!(:category, :category_with_definition)
      fab!(:subcategory) { Fabricate(:category_with_definition, parent_category: category) }
      fab!(:category_topic) { Fabricate(:topic, category: category, user: user) }
      fab!(:category_post1) { create_post(user: user, topic: category_topic) }
      fab!(:category_post2) { create_post(topic: category_topic) }
      fab!(:subcategory_topic) { Fabricate(:topic, category: subcategory, user: user) }
      fab!(:subcategory_post1) { create_post(user: user, topic: subcategory_topic) }
      fab!(:subcategory_post2) { create_post(topic: subcategory_topic) }

      it "should dismiss unread posts for the category and its subcategories" do
        sign_in(user)

        visit("/c/#{category.id}/l/unread")

        expect(topic_list_controls).to have_unread(count: 2)

        topic_list_controls.dismiss_unread

        expect(topic_list_controls).to have_unread(count: 0)
      end
    end
  end

  describe "when a user has a new topic" do
    fab!(:topic)

    it "should remove the new topic across sessions after the user dismisses it" do
      tab_1 = open_new_window(:tab)
      switch_to_window(tab_1)
      sign_in(user)
      visit("/new")

      expect(topic_list_controls).to have_new(count: 1)

      tab_2 = open_new_window(:tab)
      switch_to_window(tab_2)
      sign_in(user)
      visit("/new")

      expect(topic_list_controls).to have_new(count: 1)

      switch_to_window(tab_1)
      topic_list_controls.dismiss_new

      expect(topic_list_controls).to have_new(count: 0)

      switch_to_window(tab_2)
      expect(topic_list_controls).to have_new(count: 0)
    end
  end

  describe "when the `experimental_new_new_view_groups` site setting is enabled" do
    fab!(:group) { Fabricate(:group).tap { |g| g.add(user) } }
    fab!(:new_topic) { Fabricate(:topic, user: user) }
    fab!(:post1) { create_post(user: user) }
    fab!(:post2) { create_post(topic: post1.topic) }

    before { SiteSetting.experimental_new_new_view_groups = group.name }

    it "should remove the new topic and post across sessions after the user dismisses it" do
      tab_1 = open_new_window(:tab)
      switch_to_window(tab_1)
      sign_in(user)
      visit("/new")

      expect(topic_list_controls).to have_new(count: 2)

      tab_2 = open_new_window(:tab)
      switch_to_window(tab_2)
      sign_in(user)
      visit("/new")

      expect(topic_list_controls).to have_new(count: 2)

      switch_to_window(tab_1)
      topic_list_controls.dismiss_new
      dismiss_new_modal.click_dismiss

      expect(dismiss_new_modal).to be_closed
      expect(topic_list_controls).to have_new(count: 0)

      switch_to_window(tab_2)
      expect(topic_list_controls).to have_new(count: 0)

      switch_to_window(tab_1)
      topic_list_controls.click_latest

      expect(topic_list_controls).to have_new(count: 0)
    end

    it "displays confirmation modal with preselected options" do
      sign_in(user)

      visit("/new")

      expect(topic_list).to have_topic(new_topic)
      expect(topic_list).to have_topic(post1.topic)

      topic_list_controls.dismiss_new

      expect(dismiss_new_modal).to have_dismiss_topics_checked
      expect(dismiss_new_modal).to have_dismiss_posts_checked
      expect(dismiss_new_modal).to have_untrack_unchecked

      dismiss_new_modal.click_dismiss

      expect(topic_list).to have_no_topics
    end

    it "displays confirmation modal with replies preselected" do
      sign_in(user)

      visit("/new?subset=replies")

      expect(topic_list).to have_topic(post1.topic)

      topic_list_controls.dismiss_new

      expect(dismiss_new_modal).to have_dismiss_topics_unchecked
      expect(dismiss_new_modal).to have_dismiss_posts_checked
      expect(dismiss_new_modal).to have_untrack_unchecked

      dismiss_new_modal.click_dismiss

      expect(topic_list).to have_no_topics
    end

    it "displays confirmation modal with topics preselected" do
      sign_in(user)

      visit("/new?subset=topics")

      expect(topic_list).to have_topic(new_topic)

      topic_list_controls.dismiss_new

      expect(dismiss_new_modal).to have_dismiss_topics_checked
      expect(dismiss_new_modal).to have_dismiss_posts_unchecked
      expect(dismiss_new_modal).to have_untrack_unchecked

      dismiss_new_modal.click_dismiss

      expect(topic_list).to have_no_topics
    end

    context "with a tagged topic" do
      fab!(:tag)
      fab!(:tagged_topic) { Fabricate(:topic, tags: [tag]) }
      fab!(:tagged_first_post) { Fabricate(:post, topic: tagged_topic) }

      it "works on tag routes" do
        sign_in(user)

        visit("/tag/#{tag.name}/l/new")

        expect(topic_list).to have_topics(count: 1)
        expect(topic_list).to have_topic(tagged_first_post.topic)

        topic_list_controls.dismiss_new
        dismiss_new_modal.click_dismiss

        expect(topic_list).to have_no_topics

        visit("/new")
        expect(topic_list).to have_topic(post1.topic)
      end

      it "works on regular routes after visiting tagged route" do
        sign_in(user)

        visit("/tag/#{tag.name}/l/new")

        expect(topic_list).to have_topics(count: 1)

        discovery.tag_drop.select_row_by_value("all-tags")

        expect(topic_list).to have_topics(count: 3)

        discovery.nav_item("new").click

        topic_list_controls.dismiss_new
        dismiss_new_modal.click_dismiss

        expect(topic_list).to have_no_topics
      end
    end
  end
end
