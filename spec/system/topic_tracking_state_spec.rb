# frozen_string_literal: true

describe "Topic tracking state", type: :system do
  fab!(:user) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:tag)
  fab!(:other_tag, :tag)

  let(:sidebar) { PageObjects::Components::NavigationMenu::Sidebar.new }
  let(:topic_list) { PageObjects::Components::TopicList.new }

  before do
    SiteSetting.tagging_enabled = true
    SiteSetting.navigation_menu = "sidebar"
  end

  def publish_new_topic(tags)
    new_topic = Fabricate(:topic, tags:)
    Fabricate(:post, topic: new_topic)
    TopicTrackingState.publish_new(new_topic)
    new_topic
  end

  describe "incoming topic notifications on tag page" do
    it "shows incoming count when new topic is created with the tag" do
      existing_topic = Fabricate(:topic, tags: [tag])
      Fabricate(:post, topic: existing_topic)

      sign_in(user)
      visit("/tag/#{tag.name}")

      expect(topic_list).to have_topics(count: 1)

      new_topic = publish_new_topic([tag])

      try_until_success(reason: "relies on MessageBus updates") do
        expect(page).to have_css(".show-more", text: /1.*new/)
      end

      find(".show-more").click
      expect(topic_list).to have_topics(count: 2)
      expect(topic_list).to have_topic(new_topic)
    end
  end

  describe "muted tags" do
    fab!(:muted_tag, :tag)

    before do
      TagUser.create!(
        user: user,
        tag: muted_tag,
        notification_level: TagUser.notification_levels[:muted],
      )
    end

    it "filters out topics with muted tags from incoming on latest" do
      sign_in(user)
      visit("/latest")

      muted_topic = publish_new_topic([muted_tag])
      normal_topic = publish_new_topic([])
      puts "Published topics: #{muted_topic.id} (muted), #{normal_topic.id} (normal)"

      try_until_success(reason: "relies on MessageBus updates") do
        expect(page).to have_css(".show-more", text: /1.*new/)
      end

      find(".show-more").click
      expect(topic_list).to have_topic(normal_topic)
      expect(topic_list).to have_no_topic(muted_topic)
    end
  end
end
