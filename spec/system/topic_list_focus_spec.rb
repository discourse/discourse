# frozen_string_literal: true

describe "Topic list focus", type: :system do
  fab!(:topics) { Fabricate.times(10, :post).map(&:topic) }

  before_all do
    sidebar_url = Fabricate(:sidebar_url, name: "my topic link", value: "/t/#{topics[4].id}")

    Fabricate(
      :sidebar_section_link,
      sidebar_section:
        SidebarSection.find_by(section_type: SidebarSection.section_types[:community]),
      linkable: sidebar_url,
    )
  end

  let(:discovery) { PageObjects::Pages::Discovery.new }
  let(:topic) { PageObjects::Pages::Topic.new }

  def focussed_topic_id
    page.evaluate_script(
      "document.activeElement.closest('.topic-list-item')?.dataset.topicId",
    )&.to_i
  end

  def focussed_post_id
    page.evaluate_script("document.activeElement.closest('.onscreen-post')?.dataset.postId")&.to_i
  end

  it "refocusses last clicked topic when going back to topic list" do
    visit("/latest")
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

  it "refocusses properly when navigating via the 'last activity' link" do
    visit("/latest")

    # Visit topic via activity column and keyboard
    discovery.topic_list.visit_topic_last_reply_via_keyboard(topics[2])
    expect(topic).to have_topic_title(topics[2].title)

    # Going back to the topic-list should re-focus
    page.go_back
    expect(page).to have_css("body.navigation-topics")
    expect(focussed_topic_id).to eq(topics[2].id)

    # Visit topic via keyboard using posts map (OP button)
    discovery.topic_list.visit_topic_first_reply_via_keyboard(topics[4])
    expect(topic).to have_topic_title(topics[4].title)

    # Going back to the topic-list should re-focus
    page.go_back
    expect(page).to have_css("body.navigation-topics")
    expect(focussed_topic_id).to eq(topics[4].id)
  end

  it "does not refocus topic when visiting via something other than topic list" do
    visit("/latest")

    # Clicking sidebar link should visit topic
    find(".sidebar-section-link[data-link-name='my topic link']").click
    expect(topic).to have_topic_title(topics[4].title)

    # Going back to the topic-list should not re-focus
    page.go_back
    expect(page).to have_css("body.navigation-topics")
    expect(focussed_topic_id).to eq(nil)
  end

  it "refocusses properly when there are multiple pages of topics" do
    extra_topics = Fabricate.times(25, :post).map(&:topic)
    oldest_topic = Fabricate(:post).topic
    oldest_topic.update(bumped_at: 1.day.ago)

    visit("/latest")

    # Scroll to bottom for infinite load
    page.execute_script <<~JS
      document.querySelectorAll('.topic-list-item')[24].scrollIntoView(true);
    JS

    # Click a topic
    discovery.topic_list.visit_topic(oldest_topic)
    expect(topic).to have_topic_title(oldest_topic.title)

    # Going back to the topic-list should re-focus
    page.go_back
    expect(page).to have_css("body.navigation-topics")
    expect(focussed_topic_id).to eq(oldest_topic.id)
  end
end
