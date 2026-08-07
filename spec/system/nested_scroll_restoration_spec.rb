# frozen_string_literal: true

RSpec.describe "Nested view scroll restoration" do
  fab!(:user) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:topic) { Fabricate(:topic, user: user) }
  fab!(:op) { Fabricate(:post, topic: topic, user: user, post_number: 1) }

  fab!(:root_posts) do
    60.times.map do |index|
      Fabricate(
        :post,
        topic: topic,
        user: Fabricate(:user),
        raw: "Root post number #{index + 1}\n\n#{"filler text " * 300}",
        reply_to_post_number: nil,
      )
    end
  end

  let(:nested_view) { PageObjects::Pages::NestedView.new }

  before do
    SiteSetting.nested_replies_enabled = true
    Fabricate(:nested_topic, topic: topic)

    sign_in(user)
  end

  it "lets the user keep scrolling after returning to a topic", :aggregate_failures do
    nested_view.visit_nested(topic)
    expect(nested_view).to have_nested_view

    nested_view.scroll_to_position(5000)
    nested_view.visit_nested(topic)
    expect(nested_view).to have_nested_view

    try_until_success(reason: "scroll anchor restores after render") do
      expect(nested_view.current_scroll_position).to be_within(10).of(5000)
    end

    positions = nested_view.scroll_during_pending_restore(distance: 3000)

    expect(positions["restored"]).to be_within(10).of(5000)
    expect(positions["afterUserScroll"]).to be > positions["restored"] + 2500
    expect(positions["afterRetries"]).to be_within(10).of(positions["afterUserScroll"])
  end

  it "restores after pagination when the user does not scroll", :aggregate_failures do
    target_post = root_posts[24]

    nested_view.visit_nested(topic).disable_cloaking
    expect(nested_view).to have_root_post_count(20)

    nested_view.scroll_to_bottom
    expect(nested_view).to have_root_post_count(40)

    nested_view.scroll_to_post(target_post)
    saved_position = nested_view.current_scroll_position

    nested_view.visit_nested(topic)
    expect(nested_view).to have_root_post_count(20)

    try_until_success(reason: "scroll anchor restores after paginated roots load") do
      expect(nested_view).to have_root_post_count(40)
      expect(nested_view.current_scroll_position).to be_within(10).of(saved_position)
    end
  end

  it "lets the user keep scrolling when pagination loads the restored post", :aggregate_failures do
    target_post = root_posts[24]

    nested_view.visit_nested(topic).disable_cloaking
    expect(nested_view).to have_root_post_count(20)

    nested_view.scroll_to_bottom
    expect(nested_view).to have_root_post_count(40)

    nested_view.scroll_to_post(target_post)
    saved_position = nested_view.current_scroll_position

    nested_view.with_root_pagination_paused(topic) do |pagination|
      nested_view.reload_with_pending_pagination
      pagination.wait
      expect(nested_view).to have_root_post_count(20)

      restored_position = nested_view.current_scroll_position
      after_user_scroll_position = nested_view.user_scroll_by(distance: -1000)
      centered_post_number = nested_view.centered_root_post_number
      pagination.resume

      expect(restored_position).to be < saved_position
      expect(after_user_scroll_position).to be < restored_position - 500
      expect(nested_view).to have_root_post_count(40)
      expect(nested_view.scroll_position_after_restore_window).to be < saved_position
      expect(nested_view.centered_root_post_number).to eq(centered_post_number)
    end
  end
end
