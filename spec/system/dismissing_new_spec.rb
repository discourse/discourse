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

    it "should remove the unread post across sessions after the user dismisses it" do
      sign_in(user)

      visit("/unread")

      expect(topic_list_controls).to have_unread(count: 1)

      using_session(:tab_1) do
        sign_in(user)

        visit("/unread")

        expect(topic_list_controls).to have_unread(count: 1)
      end

      topic_list_controls.dismiss_unread

      expect(topic_list_controls).to have_unread(count: 0)

      using_session(:tab_1) { expect(topic_list_controls).to have_unread(count: 0) }
    end

    it "should untrack topics across sessions after the user dismisses it" do
      sign_in(user)

      visit("/unread")

      using_session(:tab_1) do
        sign_in(user)

        visit("/t/#{topic.id}")

        expect(topic_view).to have_tracking_status("tracking")
      end

      topic_list_controls.dismiss_unread(untrack: true)

      using_session(:tab_1) { expect(topic_view).to have_tracking_status("regular") }
    end

    context "with subcategories" do
      fab!(:category) { Fabricate(:category_with_definition) }
      fab!(:subcategory) { Fabricate(:category_with_definition, parent_category: category) }
      fab!(:subcategory_topic) { Fabricate(:topic, category: subcategory, user: user) }
      fab!(:subcategory_post1) { create_post(user: user, topic: subcategory_topic) }
      fab!(:subcategory_post2) { create_post(topic: subcategory_topic) }

      it "should dismiss unread posts in subcategories when they are included in the parent category topic list" do
        sign_in(user)

        visit("/c/#{category.id}/l/unread")

        expect(topic_list_controls).to have_unread(count: 1)

        topic_list_controls.dismiss_unread

        expect(topic_list_controls).to have_unread(count: 0)
      end
    end
  end

  describe "when a user has a new topic" do
    fab!(:topic)

    it "should remove the new topic across sessions after the user dismisses it" do
      sign_in(user)

      visit("/new")

      expect(topic_list_controls).to have_new(count: 1)

      using_session(:tab_1) do
        sign_in(user)

        visit("/new")

        expect(topic_list_controls).to have_new(count: 1)
      end

      topic_list_controls.dismiss_new

      expect(topic_list_controls).to have_new(count: 0)

      using_session(:tab_1) { expect(topic_list_controls).to have_new(count: 0) }
    end
  end

  describe "when the `experimental_new_new_view_groups` site setting is enabled" do
    fab!(:group) { Fabricate(:group).tap { |g| g.add(user) } }
    fab!(:new_topic) { Fabricate(:topic, user: user) }
    fab!(:post1) { create_post(user: user) }
    fab!(:post2) { create_post(topic: post1.topic) }

    before { SiteSetting.experimental_new_new_view_groups = group.name }

    it "should remove the new topic and post across sessions after the user dismisses it" do
      sign_in(user)

      visit("/new")

      expect(topic_list_controls).to have_new(count: 2)

      using_session(:tab_1) do
        sign_in(user)

        visit("/new")

        expect(topic_list_controls).to have_new(count: 2)
      end

      topic_list_controls.dismiss_new
      dismiss_new_modal.click_dismiss

      expect(topic_list_controls).to have_new(count: 0)

      using_session(:tab_1) { expect(topic_list_controls).to have_new(count: 0) }

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
