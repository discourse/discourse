# frozen_string_literal: true

describe "Admin dashboard Support section" do
  fab!(:admin)
  fab!(:support_category)
  fab!(:author) { Fabricate(:user, trust_level: TrustLevel[1]) }
  fab!(:staff_replier, :moderator)
  fab!(:member_replier) { Fabricate(:user, trust_level: TrustLevel[2]) }

  let(:dashboard) { PageObjects::Pages::AdminDashboard.new }
  let(:support) { PageObjects::Components::AdminDashboardSupport.new }

  before do
    SiteSetting.solved_enabled = true
    SiteSetting.dashboard_improvements = true

    # Resolved: staff makes the first reply, which is accepted as the solution.
    resolved = Fabricate(:topic, category: support_category, user: author)
    Fabricate(:post, topic: resolved, user: author)
    staff_answer = Fabricate(:post, topic: resolved, user: staff_replier)
    Fabricate(:solved_topic, topic: resolved, answer_post: staff_answer)

    # In progress: a member has replied but nothing is accepted.
    in_progress = Fabricate(:topic, category: support_category, user: author)
    Fabricate(:post, topic: in_progress, user: author)
    Fabricate(:post, topic: in_progress, user: member_replier)

    # Unanswered: only the opening post.
    unanswered = Fabricate(:topic, category: support_category, user: author)
    Fabricate(:post, topic: unanswered, user: author)

    sign_in(admin)
  end

  it "shows support analytics for the community's support topics" do
    dashboard.visit
    support.scroll_into_view

    expect(support).to have_section
    expect(support).to have_kpi("Resolution rate")
    expect(support).to have_kpi("Staff involvement")
    expect(support).to have_kpi("Avg. first reply")

    expect(support).to have_topic_outcome("Resolved", count: 1)
    expect(support).to have_topic_outcome("In progress", count: 1)
    expect(support).to have_topic_outcome("Unanswered", count: 1)

    expect(support).to have_answerer("Staff")
    expect(support).to have_answerer("Members")

    expect(support).to have_response_time_bucket("< 1 hour")

    # With a single support category there is nothing to filter between.
    expect(support).to have_no_category_filter
  end

  context "with multiple support categories" do
    fab!(:other_support_category, :support_category)
    fab!(:moderator)

    it "saves an admin's category selection when the picker closes, and persists it across a refresh" do
      dashboard.visit
      support.scroll_into_view
      expect(support).to have_category_filter
      expect(support).to have_no_selected_category(support_category)

      support.select_category(support_category)
      support.close_category_filter

      support.expand_category_filter
      expect(support).to have_selected_category(support_category)

      dashboard.visit
      support.scroll_into_view

      support.expand_category_filter
      expect(support).to have_selected_category(support_category)
    end

    it "does not persist a moderator's category selection" do
      sign_in(moderator)

      dashboard.visit
      support.scroll_into_view
      support.select_category(support_category)
      support.close_category_filter

      dashboard.visit
      support.scroll_into_view
      support.expand_category_filter

      expect(support).to have_no_selected_category(support_category)
    end
  end
end
