# frozen_string_literal: true

describe "Filtering topics", type: :system, js: true do
  fab!(:user) { Fabricate(:user) }
  fab!(:topic) { Fabricate(:topic) }
  fab!(:closed_topic) { Fabricate(:topic, closed: true) }
  let(:topic_list) { PageObjects::Components::TopicList.new }

  before { SiteSetting.experimental_topics_filter = true }

  it "should allow users to input a custom query string to filter through topics" do
    sign_in(user)

    visit("/filter")

    expect(topic_list).to have_topic(topic)
    expect(topic_list).to have_topic(closed_topic)

    topic_query_filter = PageObjects::Components::TopicQueryFilter.new
    topic_query_filter.fill_in("status:open")

    expect(topic_list).to have_topic(topic)
    expect(topic_list).to have_no_topic(closed_topic)
    expect(page).to have_current_path("/filter?status=open")

    topic_query_filter.fill_in("status:closed")

    expect(topic_list).to have_no_topic(topic)
    expect(topic_list).to have_topic(closed_topic)
    expect(page).to have_current_path("/filter?status=closed")
  end

  it "should filter topics when 'status' query params is present" do
    sign_in(user)

    visit("/filter?status=open")

    expect(topic_list).to have_topic(topic)
    expect(topic_list).to have_no_topic(closed_topic)
  end
end
