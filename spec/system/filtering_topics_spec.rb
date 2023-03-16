# frozen_string_literal: true

describe "Filtering topics", type: :system, js: true do
  fab!(:user) { Fabricate(:user) }
  fab!(:topic) { Fabricate(:topic) }
  fab!(:closed_topic) { Fabricate(:topic, closed: true) }
  let(:topic_list) { PageObjects::Components::TopicList.new }

  before { SiteSetting.experimental_topics_filter = true }

  it "should allow users to enter a custom query string to filter through topics" do
    sign_in(user)

    visit("/filter")

    expect(topic_list).to have_topic(topic)
    expect(topic_list).to have_topic(closed_topic)

    topic_query_filter = PageObjects::Components::TopicQueryFilter.new
    topic_query_filter.fill_in("status:open")

    expect(topic_list).to have_topic(topic)
    expect(topic_list).to have_no_topic(closed_topic)
    expect(page).to have_current_path("/filter?q=status%3Aopen")

    topic_query_filter.fill_in("status:closed")

    expect(topic_list).to have_no_topic(topic)
    expect(topic_list).to have_topic(closed_topic)
    expect(page).to have_current_path("/filter?q=status%3Aclosed")
  end

  it "should filter topics when 'q' query params is present" do
    sign_in(user)

    visit("/filter?q=status:open")

    expect(topic_list).to have_topic(topic)
    expect(topic_list).to have_no_topic(closed_topic)
  end
end
