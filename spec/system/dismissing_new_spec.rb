# frozen_string_literal: true

RSpec.describe "Dismissing New", type: :system do
  fab!(:user) { Fabricate(:user) }

  let(:topic_list_controls) { PageObjects::Components::TopicListControls.new }
  let(:topic_list) { PageObjects::Components::TopicList.new }
  let(:dismiss_new_modal) { PageObjects::Modals::DismissNew.new }

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
  end

  describe "when a user has a new topic" do
    fab!(:topic) { Fabricate(:topic) }

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
  end
end
