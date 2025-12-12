# frozen_string_literal: true

describe "Embed mode", type: :system do
  fab!(:topic)
  fab!(:post) { Fabricate(:post, topic: topic) }

  let(:topic_page) { PageObjects::Pages::Topic.new }

  it "applies embed-mode class to body when embed_mode=true" do
    visit("/t/#{topic.slug}/#{topic.id}?embed_mode=true")

    expect(page).to have_css("body.embed-mode")
  end

  it "does not apply embed-mode class without the param" do
    visit("/t/#{topic.slug}/#{topic.id}")

    expect(page).to have_no_css("body.embed-mode")
  end

  it "hides suggested topics in embed mode" do
    Fabricate(:post) # create another topic for suggestions
    visit("/t/#{topic.slug}/#{topic.id}?embed_mode=true")

    expect(page).to have_css("body.embed-mode")
    expect(page).to have_no_css(".suggested-topics")
  end

  it "loads topic content without JS errors" do
    visit("/t/#{topic.slug}/#{topic.id}?embed_mode=true")

    expect(page).to have_css("body.embed-mode")
    expect(topic_page).to have_topic_title(topic.title)
    expect(page).to have_css("#post_1")
  end
end
