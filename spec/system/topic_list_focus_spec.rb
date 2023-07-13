# frozen_string_literal: true

describe "Topic list focus", type: :system do
  let!(:topics) { Fabricate.times(10, :post).map(&:topic) }

  before { Fabricate(:admin) }

  let(:discovery) { PageObjects::Pages::Discovery.new }
  let(:topic) { PageObjects::Pages::Topic.new }

  def focussed_topic_id
    page.evaluate_script(
      "document.activeElement.closest('.topic-list-item')?.dataset.topicId",
    )&.to_i
  end

  it "refocusses last clicked topic when going back to topic list" do
    visit("/")
    expect(page).to have_css("body.navigation-topics")
    expect(discovery.topic_list).to have_topics

    # Click a topic
    discovery.topic_list.visit_topic(topics[5])
    expect(topic).to have_topic_title(topics[5].title)

    # Going back to the topic-list should re-focus
    page.go_back
    expect(page).to have_css("body.navigation-topics")
    expect(focussed_topic_id).to eq(topics[5].id)

    # Click topic again
    discovery.topic_list.visit_topic(topics[5])
    expect(topic).to have_topic_title(topics[5].title)

    # Visiting a topic list another way should not focus
    find(".sidebar-section-link[data-link-name='everything']").click
    expect(page).to have_css("body.navigation-topics")
    expect(focussed_topic_id).to eq(nil)
  end
end
