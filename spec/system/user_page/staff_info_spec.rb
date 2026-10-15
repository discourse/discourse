# frozen_string_literal: true

describe "Viewing user staff info as an admin" do
  fab!(:user)
  fab!(:admin)
  let(:user_page) { PageObjects::Pages::User.new }

  before { sign_in(admin) }

  context "for warnings" do
    fab!(:topic) { Fabricate(:private_message_topic, user: admin, recipient: user) }
    fab!(:user_warning) { UserWarning.create!(user: user, created_by: admin, topic: topic) }

    it "shows the user's warning link and count" do
      user_page.visit(user).click_staff_info_warnings_link(user, warnings_count: 1)

      expect(user_page).to have_warning_messages_path(user)
    end
  end

  context "for silencings" do
    fab!(:silencing) do
      Fabricate(:user_history, action: UserHistory.actions[:silence_user], target_user: user)
    end
    it "shows the user's silencing link and count" do
      user_page.visit(user)
      silencings_counters =
        browser_root.locator(".staff-counters .silencings").filter(visible: true)
      expect(silencings_counters).to PlaywrightMatchers.contain_text(
        browser_text_pattern("1"),
        useInnerText: true,
      )

      user_page.click_staff_info_silencings_link
      expect(browser_page).to PlaywrightMatchers.have_url(
        %r{^https?://[^/]+#{Regexp.escape("/admin/logs/staff_action_logs")}(?:\?.*)?$},
      )

      current_url = browser_page.url
      uri = URI.parse(current_url)
      filters = JSON.parse(URI.decode_www_form(uri.query).to_h["filters"])

      expect(filters["target_user"]).to eq(user.username)
      expect(filters["action_name"]).to eq("silence_user")
    end
  end

  context "for flags given" do
    fab!(:flagged_post) { Fabricate(:post, user: admin) }

    before do
      Group.refresh_automatic_groups!
      PostActionCreator.create(user, flagged_post, :inappropriate)
    end

    it "shows count and links to review queue filtered by flagger" do
      user_page.visit(user)

      expect(user_page).to have_staff_counter_flags_given(count: 1)

      user_page.click_staff_info_flags_given_link

      expect(browser_page).to PlaywrightMatchers.have_url(%r{/review})
      expect(browser_page).to PlaywrightMatchers.have_url(/flagged_by=#{user.username}/)
      expect(browser_page).to PlaywrightMatchers.have_url(/status=approved/)
    end
  end

  context "for flags" do
    fab!(:reviewable_flagged_post) { Fabricate(:reviewable_flagged_post, target_created_by: user) }
    fab!(:reviewable_queued_post) { Fabricate(:reviewable_queued_post, target_created_by: user) }

    let(:review_page) { PageObjects::Pages::Review.new }

    it "shows count and links to review queue for all reviewable types" do
      user_page.visit(user)

      expect(user_page).to have_staff_counter_flags(count: 2)

      user_page.click_staff_info_flags_link

      expect(review_page).to have_reviewables([reviewable_flagged_post, reviewable_queued_post])
    end
  end
end
