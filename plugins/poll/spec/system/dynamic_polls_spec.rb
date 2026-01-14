# frozen_string_literal: true

describe "Dynamic polls", type: :system do
  fab!(:admin)
  fab!(:topic)

  let(:topic_page) { PageObjects::Pages::Topic.new }
  let(:poll_page) { PageObjects::Pages::Poll.new(topic_page: topic_page) }

  before do
    sign_in admin
    SiteSetting.poll_create_allowed_groups = Group::AUTO_GROUPS[:admins].to_s
  end

  def cook_poll(raw)
    PostCreator.create!(admin, topic_id: topic.id, raw: raw)
  end

  it "allows editing poll options after window while preserving votes on existing options" do
    post = cook_poll(<<~MD)
      [poll dynamic=true]
      * A
      * B
      [/poll]
    MD

    topic_page.visit_topic(topic)
    expect(poll_page).to have_poll_for_post(post)

    poll_page.vote_for_option(post, "A")

    expect(poll_page).to have_vote_count(post, 1)

    # Advance time beyond edit window
    freeze_time (SiteSetting.poll_edit_window_mins + 1).minutes.from_now

    # Edit the poll: add C, remove B, keep A (vote should stay)
    new_raw = <<~MD
      [poll dynamic=true]
      * A
      * C
      [/poll]
    MD

    PostRevisor.new(post, post.topic).revise!(admin, { raw: new_raw }, revised_at: Time.zone.now)

    visit(current_url)

    # Ensure A still exists, B removed, C added
    expect(poll_page).to have_poll_for_post(post)
    expect(poll_page).to have_option(post, "A")
    expect(poll_page).to have_option(post, "C")
    expect(poll_page).to have_no_option(post, "B")

    expect(poll_page).to have_vote_count(post, 1)

    expect(poll_page.find_poll_for_post(post)).to have_css(
      ".poll-info_instructions li.is-dynamic",
      text: I18n.t("js.poll.dynamic.enabled_hint"),
    )
  end
end
