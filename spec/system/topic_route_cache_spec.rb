# frozen_string_literal: true

describe "Topic route cache" do
  fab!(:topic_1, :topic)
  fab!(:topic_2, :topic)
  before do
    Fabricate.times(5, :post, topic: topic_1)
    Fabricate.times(5, :post, topic: topic_2)
  end

  let(:topic_page) { PageObjects::Pages::Topic.new }

  it "returns to the same topic when navigating back from the topic list" do
    topic_page.visit_topic(topic_1)
    expect(topic_page).to have_topic_title(topic_1.title)
    expect(topic_page).to have_post_number(1)

    visit("/latest")
    expect(page).to have_css("body.navigation-topics")

    page.go_back

    expect(page).to have_current_path(%r{/t/#{topic_1.slug}/#{topic_1.id}})
    expect(topic_page).to have_topic_title(topic_1.title)
    expect(topic_page).to have_post_number(1)
  end

  it "shows the correct topic when navigating back across two topic visits" do
    topic_page.visit_topic(topic_1)
    expect(topic_page).to have_topic_title(topic_1.title)

    topic_page.visit_topic(topic_2)
    expect(topic_page).to have_topic_title(topic_2.title)

    page.go_back

    expect(page).to have_current_path(%r{/t/#{topic_1.slug}/#{topic_1.id}})
    expect(topic_page).to have_topic_title(topic_1.title)
    expect(topic_page).to have_post_number(1)
  end
end
