# frozen_string_literal: true

describe "Ember route-scroll-manager service" do
  fab!(:topic)

  before do
    Fabricate(:admin)
    Fabricate.times(50, :post)
    Fabricate.times(20, :post, topic: topic)
  end

  let(:discovery) { PageObjects::Pages::Discovery.new }

  def current_scroll_y
    page.evaluate_script("window.scrollY")
  end

  it "scrolls to top when navigating to new routes, and remembers scroll position when going back" do
    visit("/")
    expect(page).to have_css("body.navigation-topics")
    expect(discovery.topic_list).to have_topics

    page.execute_script <<~JS
      document.querySelectorAll('.topic-list-item')[10].scrollIntoView(true);
    JS

    topic_list_scroll_y = current_scroll_y
    expect(topic_list_scroll_y).to be > 0

    find(".sidebar-section-link[data-link-name='all-categories']").click

    expect(page).to have_css("body.navigation-categories")
    expect(current_scroll_y).to eq(0)

    page.go_back

    expect(page).to have_css("body.navigation-topics")
    expect(discovery.topic_list).to have_topics
    expect(current_scroll_y).to eq(topic_list_scroll_y)

    # Clicking site logo triggers refresh and scrolls to top
    click_logo
    expect(current_scroll_y).to eq(0)
  end

  it "scrolls to the top when navigating from a topic to the homepage" do
    visit("/t/#{topic.slug}/#{topic.id}")
    expect(page).to have_css("#post_20")

    page.execute_script("window.scrollTo(0, document.body.scrollHeight)")
    expect(current_scroll_y).to be > 0

    click_logo

    expect(page).to have_css("body.navigation-topics")
    expect(discovery.topic_list).to have_topics
    expect(current_scroll_y).to eq(0)
  end
end
