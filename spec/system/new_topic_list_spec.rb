# frozen_string_literal: true

describe "New topic list", type: :system do
  fab!(:user)
  fab!(:group) { Fabricate(:group, users: [user]) }
  fab!(:category)
  fab!(:tag)

  fab!(:new_reply) { Fabricate(:new_reply_topic, current_user: user) }
  fab!(:new_topic) { Fabricate(:post).topic }
  fab!(:old_topic) { Fabricate(:read_topic, current_user: user) }

  fab!(:new_reply_in_category) do
    Fabricate(:new_reply_topic, category: category, current_user: user)
  end

  fab!(:new_topic_in_category) do
    Fabricate(:post, topic: Fabricate(:topic, category: category)).topic
  end

  fab!(:old_topic_in_category) { Fabricate(:read_topic, category: category, current_user: user) }
  fab!(:new_reply_with_tag) { Fabricate(:new_reply_topic, tags: [tag], current_user: user) }

  fab!(:new_topic_with_tag) { Fabricate(:post, topic: Fabricate(:topic, tags: [tag])).topic }
  fab!(:old_topic_with_tag) { Fabricate(:read_topic, tags: [tag], current_user: user) }

  let(:topic_list) { PageObjects::Components::TopicList.new }
  let(:tabs_toggle) { PageObjects::Components::NewTopicListToggle.new }

  before { sign_in(user) }

  shared_examples "new list new topics and replies toggle" do
    context "when the new new view is enabled" do
      before { SiteSetting.experimental_new_new_view_groups = group.name }

      it "shows all new topics and replies by default" do
        visit("/new")

        expect(topic_list).to have_topics(count: 6)
        [
          new_reply,
          new_topic,
          new_reply_in_category,
          new_topic_in_category,
          new_reply_with_tag,
          new_topic_with_tag,
        ].each { |topic| expect(topic_list).to have_topic(topic) }

        expect(tabs_toggle.replies_tab).to have_count(3)
        expect(tabs_toggle.topics_tab).to have_count(3)

        expect(tabs_toggle.all_tab).to be_active
        expect(tabs_toggle.replies_tab).to be_inactive
        expect(tabs_toggle.topics_tab).to be_inactive
      end

      it "respects the subset query param and activates the appropriate tab" do
        visit("/new?subset=topics")

        expect(tabs_toggle.all_tab).to be_inactive
        expect(tabs_toggle.replies_tab).to be_inactive
        expect(tabs_toggle.topics_tab).to be_active

        visit("/new?subset=replies")

        expect(tabs_toggle.all_tab).to be_inactive
        expect(tabs_toggle.replies_tab).to be_active
        expect(tabs_toggle.topics_tab).to be_inactive
      end

      it "shows only new topics when the user switches to the Topics tab" do
        visit("/new")
        tabs_toggle.topics_tab.click

        expect(topic_list).to have_topics(count: 3)
        [new_topic, new_topic_in_category, new_topic_with_tag].each do |topic|
          expect(topic_list).to have_topic(topic)
        end

        expect(tabs_toggle.all_tab).to be_inactive
        expect(tabs_toggle.replies_tab).to be_inactive
        expect(tabs_toggle.topics_tab).to be_active

        expect(tabs_toggle.replies_tab).to have_count(3)
        expect(tabs_toggle.topics_tab).to have_count(3)

        expect(page).to have_current_path("/new?subset=topics")
      end

      it "shows only topics with new replies when the user switches to the Replies tab" do
        visit("/new")
        tabs_toggle.replies_tab.click

        expect(topic_list).to have_topics(count: 3)
        [new_reply, new_reply_in_category, new_reply_with_tag].each do |topic|
          expect(topic_list).to have_topic(topic)
        end

        expect(tabs_toggle.all_tab).to be_inactive
        expect(tabs_toggle.replies_tab).to be_active
        expect(tabs_toggle.topics_tab).to be_inactive

        expect(tabs_toggle.replies_tab).to have_count(3)
        expect(tabs_toggle.topics_tab).to have_count(3)

        expect(page).to have_current_path("/new?subset=replies")
      end

      it "strips out the subset query params when switching back to the All tab from any of the other tabs" do
        visit("/new")
        tabs_toggle.replies_tab.click

        expect(tabs_toggle.all_tab).to be_inactive
        expect(tabs_toggle.replies_tab).to be_active

        expect(page).to have_current_path("/new?subset=replies")

        tabs_toggle.all_tab.click

        expect(tabs_toggle.all_tab).to be_active
        expect(tabs_toggle.replies_tab).to be_inactive
        expect(page).to have_current_path("/new")
      end

      it "live-updates the counts shown on the tabs" do
        visit("/new")

        expect(tabs_toggle.replies_tab).to have_count(3)
        expect(tabs_toggle.topics_tab).to have_count(3)

        TopicUser.update_last_read(user, new_reply_in_category.id, 2, 1, 1)

        expect(tabs_toggle.replies_tab).to have_count(2)
        expect(tabs_toggle.topics_tab).to have_count(3)

        TopicUser.update_last_read(user, new_topic.id, 1, 1, 1)

        expect(tabs_toggle.replies_tab).to have_count(2)
        expect(tabs_toggle.topics_tab).to have_count(2)
      end

      context "when the /new topic list is scoped to a category" do
        it "shows new topics and replies in the category" do
          visit("/c/#{category.slug}/#{category.id}/l/new")
          expect(topic_list).to have_topics(count: 2)
          expect(topic_list).to have_topic(new_reply_in_category)
          expect(topic_list).to have_topic(new_topic_in_category)

          expect(tabs_toggle.all_tab).to be_active
          expect(tabs_toggle.replies_tab).to be_inactive
          expect(tabs_toggle.topics_tab).to be_inactive

          expect(tabs_toggle.replies_tab).to have_count(1)
          expect(tabs_toggle.topics_tab).to have_count(1)
        end

        it "shows only new topics in the category when the user switches to the Topics tab" do
          visit("/c/#{category.slug}/#{category.id}/l/new")
          tabs_toggle.topics_tab.click

          expect(topic_list).to have_topics(count: 1)
          expect(topic_list).to have_topic(new_topic_in_category)

          expect(tabs_toggle.all_tab).to be_inactive
          expect(tabs_toggle.replies_tab).to be_inactive
          expect(tabs_toggle.topics_tab).to be_active

          expect(tabs_toggle.replies_tab).to have_count(1)
          expect(tabs_toggle.topics_tab).to have_count(1)

          expect(page).to have_current_path(
            "/c/#{category.slug}/#{category.id}/l/new?subset=topics",
          )
        end

        it "shows only topics with new replies in the category when the user switches to the Replies tab" do
          visit("/c/#{category.slug}/#{category.id}/l/new")
          tabs_toggle.replies_tab.click

          expect(topic_list).to have_topics(count: 1)
          expect(topic_list).to have_topic(new_reply_in_category)

          expect(tabs_toggle.all_tab).to be_inactive
          expect(tabs_toggle.replies_tab).to be_active
          expect(tabs_toggle.topics_tab).to be_inactive

          expect(tabs_toggle.replies_tab).to have_count(1)
          expect(tabs_toggle.topics_tab).to have_count(1)

          expect(page).to have_current_path(
            "/c/#{category.slug}/#{category.id}/l/new?subset=replies",
          )
        end

        it "respects the subset query param and activates the appropriate tab" do
          visit("/c/#{category.slug}/#{category.id}/l/new?subset=topics")

          expect(tabs_toggle.all_tab).to be_inactive
          expect(tabs_toggle.replies_tab).to be_inactive
          expect(tabs_toggle.topics_tab).to be_active

          visit("/c/#{category.slug}/#{category.id}/l/new?subset=replies")

          expect(tabs_toggle.all_tab).to be_inactive
          expect(tabs_toggle.replies_tab).to be_active
          expect(tabs_toggle.topics_tab).to be_inactive
        end

        it "live-updates the counts shown on the tabs" do
          Fabricate(:post, topic: Fabricate(:topic, category: category))

          visit("/c/#{category.slug}/#{category.id}/l/new")

          expect(tabs_toggle.replies_tab).to have_count(1)
          expect(tabs_toggle.topics_tab).to have_count(2)

          TopicUser.update_last_read(user, new_topic_in_category.id, 1, 1, 1)

          expect(tabs_toggle.replies_tab).to have_count(1)
          expect(tabs_toggle.topics_tab).to have_count(1)
        end
      end

      context "when the /new topic list is scoped to a tag" do
        it "shows new topics and replies with the tag" do
          visit("/tag/#{tag.name}/l/new")
          expect(topic_list).to have_topics(count: 2)
          [new_reply_with_tag, new_topic_with_tag].each do |topic|
            expect(topic_list).to have_topic(topic)
          end

          expect(tabs_toggle.all_tab).to be_active
          expect(tabs_toggle.replies_tab).to be_inactive
          expect(tabs_toggle.topics_tab).to be_inactive

          expect(tabs_toggle.replies_tab).to have_count(1)
          expect(tabs_toggle.topics_tab).to have_count(1)
        end

        it "shows only new topics with the tag when the user switches to the Topics tab" do
          visit("/tag/#{tag.name}/l/new")
          tabs_toggle.topics_tab.click

          expect(topic_list).to have_topics(count: 1)
          expect(topic_list).to have_topic(new_topic_with_tag)

          expect(tabs_toggle.all_tab).to be_inactive
          expect(tabs_toggle.replies_tab).to be_inactive
          expect(tabs_toggle.topics_tab).to be_active

          expect(tabs_toggle.replies_tab).to have_count(1)
          expect(tabs_toggle.topics_tab).to have_count(1)

          expect(page).to have_current_path("/tag/#{tag.name}/l/new?subset=topics")
        end

        it "shows only topics with new replies with the tag when the user switches to the Replies tab" do
          visit("/tag/#{tag.name}/l/new")

          tabs_toggle.replies_tab.click

          expect(topic_list).to have_topics(count: 1)
          expect(topic_list).to have_topic(new_reply_with_tag)

          expect(tabs_toggle.all_tab).to be_inactive
          expect(tabs_toggle.replies_tab).to be_active
          expect(tabs_toggle.topics_tab).to be_inactive

          expect(tabs_toggle.replies_tab).to have_count(1)
          expect(tabs_toggle.topics_tab).to have_count(1)

          expect(page).to have_current_path("/tag/#{tag.name}/l/new?subset=replies")
        end

        it "respects the subset query param and activates the appropriate tab" do
          visit("/tag/#{tag.name}/l/new?subset=topics")

          expect(tabs_toggle.all_tab).to be_inactive
          expect(tabs_toggle.replies_tab).to be_inactive
          expect(tabs_toggle.topics_tab).to be_active

          visit("/tag/#{tag.name}/l/new?subset=replies")

          expect(tabs_toggle.all_tab).to be_inactive
          expect(tabs_toggle.replies_tab).to be_active
          expect(tabs_toggle.topics_tab).to be_inactive
        end

        skip "live-updates the counts shown on the tabs" do
          Fabricate(:post, topic: Fabricate(:topic, tags: [tag]))

          visit("/tag/#{tag.name}/l/new")

          expect(tabs_toggle.replies_tab).to have_count(1)
          expect(tabs_toggle.topics_tab).to have_count(2)

          TopicUser.update_last_read(user, new_topic_with_tag.id, 1, 1, 1)

          expect(tabs_toggle.replies_tab).to have_count(1)
          expect(tabs_toggle.topics_tab).to have_count(1)
        end
      end
    end

    context "when the new new view is not enabled" do
      before { SiteSetting.experimental_new_new_view_groups = "" }

      it "doesn't show the tabs toggle" do
        visit("/new")
        expect(tabs_toggle).to be_not_rendered
      end
    end
  end

  context "when on mobile", mobile: true do
    include_examples "new list new topics and replies toggle"

    context "when there are no new topics" do
      before do
        SiteSetting.experimental_new_new_view_groups = group.name

        [new_topic, new_topic_in_category, new_topic_with_tag].each do |topic|
          TopicUser.update_last_read(user, topic.id, 1, 1, 1)
        end
      end

      it "keeps the Topics tab even when there are no new topics" do
        visit("/new")

        expect(tabs_toggle.all_tab).to be_visible
        expect(tabs_toggle.replies_tab).to be_visible
        expect(tabs_toggle.topics_tab).to be_visible

        expect(tabs_toggle.replies_tab).to have_count(3)
        expect(tabs_toggle.topics_tab).to have_count(0)
      end
    end

    context "when there are no new replies" do
      before do
        SiteSetting.experimental_new_new_view_groups = group.name

        [new_reply, new_reply_in_category, new_reply_with_tag].each do |topic|
          TopicUser.update_last_read(user, topic.id, 2, 1, 1)
        end
      end

      it "keeps the Replies tab even when there are no new replies" do
        visit("/new")

        expect(tabs_toggle.all_tab).to be_visible
        expect(tabs_toggle.replies_tab).to be_visible
        expect(tabs_toggle.topics_tab).to be_visible

        expect(tabs_toggle.replies_tab).to have_count(0)
        expect(tabs_toggle.topics_tab).to have_count(3)
      end
    end
  end

  context "when on desktop" do
    include_examples "new list new topics and replies toggle"

    context "when there's only new topics" do
      before do
        SiteSetting.experimental_new_new_view_groups = group.name

        [new_reply, new_reply_in_category, new_reply_with_tag].each do |topic|
          TopicUser.update_last_read(user, topic.id, 2, 1, 1)
        end
      end

      it "doesn't render the toggle and only shows a static label for new topics" do
        visit("/new")

        expect(tabs_toggle).to be_not_rendered
        expect(find(".topic-list-header .static-label").text).to eq(
          I18n.t("js.filters.new.topics_with_count", count: 3),
        )
      end
    end

    context "when there's only new replies" do
      before do
        SiteSetting.experimental_new_new_view_groups = group.name

        [new_topic, new_topic_in_category, new_topic_with_tag].each do |topic|
          TopicUser.update_last_read(user, topic.id, 1, 1, 1)
        end
      end

      it "doesn't render the toggle and only shows a static label for new replies" do
        visit("/new")

        expect(tabs_toggle).to be_not_rendered
        expect(find(".topic-list-header .static-label").text).to eq(
          I18n.t("js.filters.new.replies_with_count", count: 3),
        )
      end
    end
  end
end
