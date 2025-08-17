# frozen_string_literal: true

describe "Dynamic polls", type: :system do
  fab!(:admin)
  fab!(:topic)

  before do
    sign_in admin
    SiteSetting.poll_create_allowed_groups = Group::AUTO_GROUPS[:admins].to_s
  end

  def cook_poll(raw)
    PostCreator.create!(admin, topic_id: topic.id, raw: raw)
  end

  it "allows editing poll options after window while preserving votes on existing options" do
    post = cook_poll(<<~MD)
      [poll dynamic-poll=true]
      * A
      * B
      [/poll]
    MD

    visit "/t/#{topic.slug}/#{topic.id}"
    expect(page).to have_css("#post_#{post.post_number} .poll")

    # Vote for option A
    within "#post_#{post.post_number} .poll" do
      find("li[data-poll-option-id] button", match: :first).click
    end

    expect(page).to have_css("#post_#{post.post_number} .poll .info-number", text: "1")

    # Advance time beyond edit window
    freeze_time (SiteSetting.poll_edit_window_mins + 1).minutes.from_now

    # Edit the poll: add C, remove B, keep A (vote should stay)
    new_raw = <<~MD
      [poll dynamic-poll=true]
      * A
      * C
      [/poll]
    MD

    PostRevisor.new(post, post.topic).revise!(admin, { raw: new_raw }, revised_at: Time.zone.now)

    visit current_url

    # Ensure A still exists, B removed, C added
    expect(page).to have_css("#post_#{post.post_number} .poll")
    within "#post_#{post.post_number} .poll" do
      expect(page).to have_selector("span.option-text", text: "A")
      expect(page).to have_selector("span.option-text", text: "C")
      expect(page).to have_no_selector("span.option-text", text: "B")
    end

    # Voter count should remain 1
    expect(page).to have_css("#post_#{post.post_number} .poll .info-number", text: "1")
  end
end
