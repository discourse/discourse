# frozen_string_literal: true

describe "New topic list", type: :system do
  fab!(:user) { Fabricate(:user) }
  fab!(:group) { Fabricate(:group, users: [user]) }
  fab!(:category) { Fabricate(:category) }
  fab!(:tag) { Fabricate(:tag) }

  fab!(:new_reply) { Fabricate(:post).topic }
  fab!(:new_topic) { Fabricate(:post).topic }
  fab!(:old_topic) { Fabricate(:post).topic }

  fab!(:new_reply_in_category) do
    Fabricate(:post, topic: Fabricate(:topic, category: category)).topic
  end
  fab!(:new_topic_in_category) do
    Fabricate(:post, topic: Fabricate(:topic, category: category)).topic
  end
  fab!(:old_topic_in_category) do
    Fabricate(:post, topic: Fabricate(:topic, category: category)).topic
  end

  fab!(:new_reply_with_tag) { Fabricate(:post, topic: Fabricate(:topic, tags: [tag])).topic }
  fab!(:new_topic_with_tag) { Fabricate(:post, topic: Fabricate(:topic, tags: [tag])).topic }
  fab!(:old_topic_with_tag) { Fabricate(:post, topic: Fabricate(:topic, tags: [tag])).topic }

  let(:topic_list) { PageObjects::Components::TopicList.new }
  let(:tabs_toggle) { PageObjects::Components::NewTopicListToggle.new }

  before do
    sign_in(user)

    [old_topic, old_topic_in_category, old_topic_with_tag].each do |topic|
      TopicUser.update_last_read(user, topic.id, 1, 1, 1)
    end

    [new_reply, new_reply_in_category, new_reply_with_tag].each do |topic|
      TopicUser.change(
        user.id,
        topic.id,
        notification_level: TopicUser.notification_levels[:tracking],
      )
      TopicUser.update_last_read(user, topic.id, 1, 1, 1)
      Fabricate(:post, topic: topic)
    end
  end

  [true, false].each do |mobile|
    desc = mobile ? "when on mobile" : "when on desktop"
    context desc, mobile: mobile do
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

          expect(tabs_toggle.all_tab).to have_count(6)
          expect(tabs_toggle.replies_tab).to have_count(3)
          expect(tabs_toggle.topics_tab).to have_count(3)
        end

        it "the All tab is the default is the default tab" do
          visit("/new")

          expect(tabs_toggle.all_tab).to be_active
          expect(tabs_toggle.replies_tab).to be_inactive
          expect(tabs_toggle.topics_tab).to be_inactive
        end

        it "respects the s (scope) query param and activates the appropriate tab" do
          visit("/new?s=topics")

          expect(tabs_toggle.all_tab).to be_inactive
          expect(tabs_toggle.replies_tab).to be_inactive
          expect(tabs_toggle.topics_tab).to be_active

          visit("/new?s=replies")

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

          expect(tabs_toggle.all_tab).to have_count(6)
          expect(tabs_toggle.replies_tab).to have_count(3)
          expect(tabs_toggle.topics_tab).to have_count(3)

          expect(current_url).to end_with("/new?s=topics")
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

          expect(tabs_toggle.all_tab).to have_count(6)
          expect(tabs_toggle.replies_tab).to have_count(3)
          expect(tabs_toggle.topics_tab).to have_count(3)

          expect(current_url).to end_with("/new?s=replies")
        end

        it "strips out the s (scope) query params when switching back to the All tab from any of the other tabs" do
          visit("/new")
          tabs_toggle.replies_tab.click

          expect(tabs_toggle.all_tab).to be_inactive
          expect(tabs_toggle.replies_tab).to be_active
          try_until_success { expect(current_url).to end_with("/new?s=replies") }

          tabs_toggle.all_tab.click

          expect(tabs_toggle.all_tab).to be_active
          expect(tabs_toggle.replies_tab).to be_inactive
          try_until_success { expect(current_url).to end_with("/new") }
        end

        it "live-updates the counts shown on the tabs" do
          visit("/new")

          expect(tabs_toggle.all_tab).to have_count(6)
          expect(tabs_toggle.replies_tab).to have_count(3)
          expect(tabs_toggle.topics_tab).to have_count(3)

          TopicUser.update_last_read(user, new_reply_in_category.id, 2, 1, 1)

          try_until_success do
            expect(tabs_toggle.all_tab).to have_count(5)
            expect(tabs_toggle.replies_tab).to have_count(2)
            expect(tabs_toggle.topics_tab).to have_count(3)
          end

          TopicUser.update_last_read(user, new_topic.id, 1, 1, 1)

          try_until_success do
            expect(tabs_toggle.all_tab).to have_count(4)
            expect(tabs_toggle.replies_tab).to have_count(2)
            expect(tabs_toggle.topics_tab).to have_count(2)
          end
        end

        context "when the /new topic list is scoped to a category" do
          it "shows new topics and replies in the category" do
            visit("/c/#{category.slug}/#{category.id}/l/new")
            expect(topic_list).to have_topics(count: 2)
            [new_reply_in_category, new_topic_in_category].each do |topic|
              expect(topic_list).to have_topic(topic)
            end

            expect(tabs_toggle.all_tab).to be_active
            expect(tabs_toggle.replies_tab).to be_inactive
            expect(tabs_toggle.topics_tab).to be_inactive

            expect(tabs_toggle.all_tab).to have_count(2)
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

            expect(tabs_toggle.all_tab).to have_count(2)
            expect(tabs_toggle.replies_tab).to have_count(1)
            expect(tabs_toggle.topics_tab).to have_count(1)

            expect(current_url).to end_with("/c/#{category.slug}/#{category.id}/l/new?s=topics")
          end

          it "shows only topics with new replies in the category when the user switches to the Replies tab" do
            visit("/c/#{category.slug}/#{category.id}/l/new")
            tabs_toggle.replies_tab.click

            expect(topic_list).to have_topics(count: 1)
            expect(topic_list).to have_topic(new_reply_in_category)

            expect(tabs_toggle.all_tab).to be_inactive
            expect(tabs_toggle.replies_tab).to be_active
            expect(tabs_toggle.topics_tab).to be_inactive

            expect(tabs_toggle.all_tab).to have_count(2)
            expect(tabs_toggle.replies_tab).to have_count(1)
            expect(tabs_toggle.topics_tab).to have_count(1)

            expect(current_url).to end_with("/c/#{category.slug}/#{category.id}/l/new?s=replies")
          end

          it "respects the s (scope) query param and activates the appropriate tab" do
            visit("/c/#{category.slug}/#{category.id}/l/new?s=topics")

            expect(tabs_toggle.all_tab).to be_inactive
            expect(tabs_toggle.replies_tab).to be_inactive
            expect(tabs_toggle.topics_tab).to be_active

            visit("/c/#{category.slug}/#{category.id}/l/new?s=replies")

            expect(tabs_toggle.all_tab).to be_inactive
            expect(tabs_toggle.replies_tab).to be_active
            expect(tabs_toggle.topics_tab).to be_inactive
          end

          it "live-updates the counts shown on the tabs" do
            visit("/c/#{category.slug}/#{category.id}/l/new")

            expect(tabs_toggle.all_tab).to have_count(2)
            expect(tabs_toggle.replies_tab).to have_count(1)
            expect(tabs_toggle.topics_tab).to have_count(1)

            TopicUser.update_last_read(user, new_reply_in_category.id, 2, 1, 1)

            try_until_success do
              expect(tabs_toggle.all_tab).to have_count(1)
              expect(tabs_toggle.replies_tab).to have_count(0)
              expect(tabs_toggle.topics_tab).to have_count(1)
            end

            TopicUser.update_last_read(user, new_topic_in_category.id, 1, 1, 1)

            try_until_success do
              expect(tabs_toggle.all_tab).to have_count(0)
              expect(tabs_toggle.replies_tab).to have_count(0)
              expect(tabs_toggle.topics_tab).to have_count(0)
            end
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

            expect(tabs_toggle.all_tab).to have_count(2)
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

            expect(tabs_toggle.all_tab).to have_count(2)
            expect(tabs_toggle.replies_tab).to have_count(1)
            expect(tabs_toggle.topics_tab).to have_count(1)

            expect(current_url).to end_with("/tag/#{tag.name}/l/new?s=topics")
          end

          it "shows only topics with new replies with the tag when the user switches to the Replies tab" do
            visit("/tag/#{tag.name}/l/new")

            tabs_toggle.replies_tab.click

            expect(topic_list).to have_topics(count: 1)
            expect(topic_list).to have_topic(new_reply_with_tag)

            expect(tabs_toggle.all_tab).to be_inactive
            expect(tabs_toggle.replies_tab).to be_active
            expect(tabs_toggle.topics_tab).to be_inactive

            expect(tabs_toggle.all_tab).to have_count(2)
            expect(tabs_toggle.replies_tab).to have_count(1)
            expect(tabs_toggle.topics_tab).to have_count(1)

            expect(current_url).to end_with("/tag/#{tag.name}/l/new?s=replies")
          end

          it "respects the s (scope) query param and activates the appropriate tab" do
            visit("/tag/#{tag.name}/l/new?s=topics")

            expect(tabs_toggle.all_tab).to be_inactive
            expect(tabs_toggle.replies_tab).to be_inactive
            expect(tabs_toggle.topics_tab).to be_active

            visit("/tag/#{tag.name}/l/new?s=replies")

            expect(tabs_toggle.all_tab).to be_inactive
            expect(tabs_toggle.replies_tab).to be_active
            expect(tabs_toggle.topics_tab).to be_inactive
          end

          it "live-updates the counts shown on the tabs" do
            visit("/tag/#{tag.name}/l/new")

            expect(tabs_toggle.all_tab).to have_count(2)
            expect(tabs_toggle.replies_tab).to have_count(1)
            expect(tabs_toggle.topics_tab).to have_count(1)

            TopicUser.update_last_read(user, new_reply_with_tag.id, 2, 1, 1)

            try_until_success do
              expect(tabs_toggle.all_tab).to have_count(1)
              expect(tabs_toggle.replies_tab).to have_count(0)
              expect(tabs_toggle.topics_tab).to have_count(1)
            end

            TopicUser.update_last_read(user, new_topic_with_tag.id, 1, 1, 1)

            try_until_success do
              expect(tabs_toggle.all_tab).to have_count(0)
              expect(tabs_toggle.replies_tab).to have_count(0)
              expect(tabs_toggle.topics_tab).to have_count(0)
            end
          end
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
end
