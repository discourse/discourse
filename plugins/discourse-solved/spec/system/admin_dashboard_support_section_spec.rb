# frozen_string_literal: true

describe "Admin dashboard Support section" do
  fab!(:admin)
  fab!(:support_category, :category)
  fab!(:author) { Fabricate(:user, trust_level: TrustLevel[1]) }
  fab!(:staff_replier, :moderator)
  fab!(:member_replier) { Fabricate(:user, trust_level: TrustLevel[2]) }

  let(:dashboard) { PageObjects::Pages::AdminDashboard.new }
  let(:support) { PageObjects::Components::AdminDashboardSupport.new }

  before do
    SiteSetting.solved_enabled = true
    SiteSetting.dashboard_improvements = true
    support_category.custom_fields[DiscourseSolved::ENABLE_ACCEPTED_ANSWERS_CUSTOM_FIELD] = "true"
    support_category.save!

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
end
