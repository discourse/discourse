# frozen_string_literal: true

describe "Ember route-scroll-manager service", type: :system do
  before do
    Fabricate(:admin)
    Fabricate.times(50, :post)
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
    try_until_success { expect(topic_list_scroll_y).to be > 0 }

    find(".sidebar-section-link[data-link-name='all-categories']").click

    expect(page).to have_css("body.navigation-categories")

    try_until_success { expect(current_scroll_y).to eq(0) }

    page.go_back

    expect(page).to have_css("body.navigation-topics")
    expect(discovery.topic_list).to have_topics

    try_until_success { expect(current_scroll_y).to eq(topic_list_scroll_y) }

    # Clicking site logo triggers refresh and scrolls to top
    click_logo
    try_until_success { expect(current_scroll_y).to eq(0) }
  end
end
