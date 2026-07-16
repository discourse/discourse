# frozen_string_literal: true

describe "Returning to the ballot on a large open poll" do
  fab!(:user)
  fab!(:topic)

  let(:topic_page) { PageObjects::Pages::Topic.new }
  let(:poll_page) { PageObjects::Pages::Poll.new(topic_page:) }

  before do
    SiteSetting.poll_enabled = true
    SiteSetting.poll_maximum_options = 100
    sign_in(user)
  end

  it "keeps the poll on screen when the user clicks back to the ballot" do
    options = (1..80).map { |i| "* Option #{format("%02d", i)}" }.join("\n")
    post = Fabricate(:post, topic:, raw: <<~RAW)
      [poll type=multiple results=always min=1 max=80]
      #{options}
      [/poll]
    RAW
    20.times do |i|
      Fabricate(:post, topic:, raw: "Reply #{i} that keeps the topic tall enough to scroll.")
    end

    page.current_window.resize_to(1100, 700)

    topic_page.visit_topic(topic)
    expect(poll_page).to have_poll_for_post(post)

    poll_page.vote_for_option(post, "Option 01")
    poll_page.vote_for_option(post, "Option 02")
    poll_page.click_cast_votes(post)

    expect(poll_page).to have_results_toggle(post)
    poll_page.scroll_results_toggle_into_view
    poll_page.click_results_toggle

    expect(poll_page).to have_voting_options(post)
    expect(poll_page).to have_poll_within_viewport
  end
end
