# frozen_string_literal: true

RSpec.describe "Tag slugs", type: :system do
  fab!(:user)
  fab!(:japanese_tag) { Fabricate(:tag, name: "猫と犬") }
  fab!(:english_tag) { Fabricate(:tag, name: "Chamomile Flowers") }
  fab!(:topic) { Fabricate(:topic, tags: [japanese_tag, english_tag]) }

  let(:topic_list) { PageObjects::Components::TopicList.new }
  let(:discovery) { PageObjects::Pages::Discovery.new }

  before { sign_in(user) }

  it "displays tags with name, id, and slug in topic list and navigates to tag page with slug and id" do
    visit("/")

    expect(topic_list).to have_topic(topic)
    expect(topic_list.topic(topic)).to have_css(".discourse-tags", text: japanese_tag.name)
    expect(topic_list.topic(topic)).to have_css(".discourse-tags", text: english_tag.name)

    within(topic_list.topic(topic)) do
      find(".discourse-tags a", text: japanese_tag.name).click
    end

    expected_slug = japanese_tag.slug_for_url
    expect(page).to have_current_path("/tag/#{expected_slug}/#{japanese_tag.id}", ignore_query: true)

    expect(page).to have_no_css(".not-found")
    expect(page).to have_content(japanese_tag.name)

    expect(topic_list).to have_topic(topic)
    expect(topic_list).to have_topics(count: 1)
  end
end
