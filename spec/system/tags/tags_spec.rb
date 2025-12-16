# frozen_string_literal: true

describe "Tags", type: :system do
  fab!(:user_tl1) { Fabricate(:user, trust_level: TrustLevel[1]) }
  fab!(:user_tl2) { Fabricate(:user, trust_level: TrustLevel[2]) }
  fab!(:user_tl3) { Fabricate(:user, trust_level: TrustLevel[3]) }

  fab!(:admin)

  fab!(:tag_one) { Fabricate(:tag, name: "tag-one") }
  fab!(:tag_two) { Fabricate(:tag, name: "tag-two") }
  fab!(:tag_three) { Fabricate(:tag, name: "tag-three") }

  fab!(:category)

  before do
    SiteSetting.tagging_enabled = true
    SiteSetting.tag_topic_allowed_groups = Group::AUTO_GROUPS[:trust_level_1]
    SiteSetting.personal_message_enabled_groups = Group::AUTO_GROUPS[:trust_level_1]
    SiteSetting.pm_tags_allowed_for_groups = Group::AUTO_GROUPS[:trust_level_2]
    SiteSetting.create_tag_allowed_groups = Group::AUTO_GROUPS[:trust_level_3]
  end

  describe "topic lists" do
    fab!(:topic_with_one_tag) do
      Fabricate(:topic, tags: [tag_one]).tap { |t| Fabricate(:post, topic: t) }
    end
    fab!(:topic_with_two_tags) do
      Fabricate(:topic, tags: [tag_one, tag_two]).tap { |t| Fabricate(:post, topic: t) }
    end
    fab!(:topic_with_no_tags) { Fabricate(:topic).tap { |t| Fabricate(:post, topic: t) } }
    fab!(:topic_in_category_with_tag) do
      Fabricate(:topic, category: category, tags: [tag_three]).tap do |t|
        Fabricate(:post, topic: t)
      end
    end
    fab!(:pm_with_tag) do
      Fabricate(
        :private_message_topic,
        tags: [tag_one],
        user: admin,
        topic_allowed_users: [
          Fabricate.build(:topic_allowed_user, user: user_tl1),
          Fabricate.build(:topic_allowed_user, user: user_tl2),
        ],
      ).tap { |t| Fabricate(:post, topic: t, user: admin) }
    end

    let(:discovery) { PageObjects::Pages::Discovery.new }
    let(:category_page) { PageObjects::Pages::Category.new }
    let(:tag_page) { PageObjects::Pages::Tag.new }
    let(:topic_list) { PageObjects::Components::TopicList.new }
    let(:user_private_messages_page) { PageObjects::Pages::UserPrivateMessages.new }
    let(:sidebar) { PageObjects::Components::NavigationMenu::Sidebar.new }

    it "displays tags on topics in topic lists" do
      sign_in(user_tl1)

      visit "/latest"

      ## Topics with tags

      # /latest
      expect(discovery.topic_list).to have_topic_tag(topic_with_one_tag, "tag-one")
      expect(discovery.topic_list).to have_topic_tags(topic_with_two_tags, "tag-one", "tag-two")
      expect(discovery.topic_list).to have_no_topic_tags(topic_with_no_tags)
      expect(discovery.tag_drop).to have_selected_name("tags") # unselected

      # /latest -> /tag/tag-one (by clicking tag on topic)
      discovery.topic_list.click_topic_tag(topic_with_one_tag, "tag-one")
      expect(page).to have_current_path("/tag/tag-one")
      expect(discovery.topic_list).to have_topic(topic_with_one_tag)

      # /c/category
      category_page.visit(category)
      expect(discovery.topic_list).to have_topic_tag(topic_in_category_with_tag, "tag-three")

      # /c/category -> /tags/c/category-slug/category-id/tag-name
      discovery.tag_drop.select_row_by_name("tag-three")
      expect(page).to have_current_path("/tags/c/#{category.slug}/#{category.id}/tag-three")
      expect(discovery.tag_drop).to have_selected_name("tag-three")
      expect(discovery.topic_list).to have_topic(topic_in_category_with_tag)

      tag_page.visit_tag(tag_one)
      # /tag/tag-one topic list filters correctly
      expect(discovery.topic_list).to have_topic(topic_with_one_tag)
      expect(discovery.topic_list).to have_topic(topic_with_two_tags)
      expect(discovery.topic_list).to have_no_topic(topic_with_no_tags)
      expect(discovery.topic_list).to have_topic_tag(topic_with_one_tag, "tag-one")

      # -> /tag/tag-one to /tag/tag-two
      discovery.topic_list.click_topic_tag(topic_with_two_tags, "tag-two")
      expect(page).to have_current_path("/tag/tag-two")
      expect(discovery.topic_list).to have_topic(topic_with_two_tags)
      expect(discovery.topic_list).to have_no_topic(topic_with_one_tag)

      ## PMs with tags

      # topic list has topic with non-visible tags (user not allowed)
      user_private_messages_page.visit(user_tl1)
      expect(topic_list).to have_topic(pm_with_tag)
      expect(topic_list).to have_no_topic_tag(pm_with_tag, "tag-one")

      # topic list has topic with tags
      sign_in(user_tl2)
      user_private_messages_page.visit(user_tl2)
      expect(topic_list).to have_topic(pm_with_tag)
      expect(topic_list).to have_topic_tag(pm_with_tag, "tag-one")

      # user messages navigate to tag page from user messages
      topic_list.click_topic_tag(pm_with_tag, "tag-one")
      expect(page).to have_current_path("/u/#{user_tl2.username}/messages/tags/tag-one")

      ## Sidebar
      expect(sidebar).to have_tag_section_links([tag_one, tag_three, tag_two])
      sidebar.click_section_link(tag_one.name)
      expect(page).to have_current_path("/tag/tag-one")
      expect(discovery.topic_list).to have_topic(topic_with_one_tag)
    end
  end

  describe "create/edit topics and PMs with tags" do
    let(:topic_page) { PageObjects::Pages::Topic.new }
    let(:composer) { PageObjects::Components::Composer.new }
    let(:mini_tag_chooser) { PageObjects::Components::SelectKit.new(".mini-tag-chooser") }

    it "creates and edits topic / PM tags" do
      sign_in(user_tl1)

      ## Topic ----

      # topic - creation with two tags
      visit "/new-topic"
      expect(composer).to be_opened

      composer.fill_title("Topic with tags test")
      composer.fill_content("This is a test topic with tags")

      mini_tag_chooser.expand
      mini_tag_chooser.search("tag-one")
      mini_tag_chooser.select_row_by_name("tag-one")
      mini_tag_chooser.search("tag-two")
      mini_tag_chooser.select_row_by_name("tag-two")
      mini_tag_chooser.collapse

      composer.submit

      # topic - tags shown in topic view
      expect(topic_page).to have_topic_title("Topic with tags test")
      expect(topic_page.topic_tags).to include("tag-one", "tag-two")

      # topic - add one and remove one tag
      topic_page.click_topic_edit_title
      expect(topic_page).to have_topic_title_editor

      mini_tag_chooser.expand
      mini_tag_chooser.unselect_by_name("tag-two")
      mini_tag_chooser.select_row_by_name("tag-three")
      topic_page.click_topic_title_submit_edit

      expect(topic_page.topic_tags).to include("tag-one", "tag-three")
      expect(topic_page.topic_tags).not_to include("tag-two")

      # topic - tag creation fails for TL1 user
      topic_page.click_topic_edit_title
      expect(topic_page).to have_topic_title_editor

      mini_tag_chooser.expand
      mini_tag_chooser.search("tag-four")
      expect(mini_tag_chooser).to have_no_option_name("tag-four")
      mini_tag_chooser.collapse_with_escape

      # topic - tag creation for TL3 user
      topic_url = page.current_url
      sign_in(user_tl3)
      visit(topic_url)

      topic_page.click_topic_edit_title
      expect(topic_page).to have_topic_title_editor

      mini_tag_chooser.expand
      mini_tag_chooser.search("tag-four")
      mini_tag_chooser.select_row_by_name("tag-four")
      mini_tag_chooser.collapse_with_escape

      topic_page.click_topic_title_submit_edit

      expect(topic_page.topic_tags).to include("tag-four")

      ## PM ----

      # PM - creation with tags fails for TL1 user
      sign_in(user_tl1)

      visit "/new-message"
      expect(composer).to be_opened
      expect(mini_tag_chooser).to be_hidden

      # PM - creation with tags for TL2 user
      sign_in(user_tl2)

      visit "/new-message"
      expect(composer).to be_opened

      composer.fill_title("PM with tags test")
      composer.fill_content("This is a test PM with tags")
      composer.select_pm_user(user_tl1.username)
      composer.select_pm_user(user_tl3.username)
      mini_tag_chooser.expand
      mini_tag_chooser.search("tag-one")
      mini_tag_chooser.select_row_by_name("tag-one")
      mini_tag_chooser.search("tag-two")
      mini_tag_chooser.select_row_by_name("tag-two")
      mini_tag_chooser.collapse_with_escape

      composer.submit

      # PM - tags shown in topic_view
      expect(page).to have_css("#topic-title")
      expect(topic_page.topic_tags).to include("tag-one", "tag-two")

      # PM - remove one and add one tag
      topic_page.click_topic_edit_title
      expect(topic_page).to have_topic_title_editor

      mini_tag_chooser.expand
      mini_tag_chooser.unselect_by_name("tag-two")
      mini_tag_chooser.select_row_by_name("tag-three")
      mini_tag_chooser.collapse_with_escape

      topic_page.click_topic_title_submit_edit

      # PM - tag updated in topic view
      expect(topic_page.topic_tags).to include("tag-one", "tag-three")
      expect(topic_page.topic_tags).not_to include("tag-two")
    end
  end
end
