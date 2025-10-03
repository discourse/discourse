# frozen_string_literal: true

describe "Solved", type: :system do
  fab!(:admin)
  fab!(:solver) { Fabricate(:user) }
  fab!(:accepter) { Fabricate(:user, name: "<b>DERP<b>") }
  fab!(:topic) { Fabricate(:post, user: admin).topic }
  fab!(:solver_post) { Fabricate(:post, topic:, user: solver, cooked: "The answer is 42") }

  let(:topic_page) { PageObjects::Pages::Topic.new }

  UNACCEPTED_BUTTON_SELECTOR = ".post-action-menu__solved-unaccepted"
  ACCEPTED_BUTTON_SELECTOR = ".post-action-menu__solved-accepted"
  ACCEPTED_ANSWER_QUOTE_SELECTOR = "aside.accepted-answer.quote"
  SOLVER_INFO_SELECTOR = ".title .accepted-answer--solver"
  ACCEPTER_INFO_SELECTOR = ".title .accepted-answer--accepter"
  QUOTE_TOGGLE_SELECTOR = "aside.accepted-answer.quote button.quote-toggle"

  before do
    SiteSetting.solved_enabled = true
    SiteSetting.allow_solved_on_all_topics = true
    SiteSetting.accept_all_solutions_allowed_groups = Group::AUTO_GROUPS[:everyone]
    SiteSetting.show_who_marked_solved = true
    SiteSetting.display_name_on_posts = true
  end

  %w[enabled disabled].each do |value|
    context "when glimmer_post_stream_mode=#{value}" do
      before { SiteSetting.glimmer_post_stream_mode = value }

      it "accepts post as solution and shows in OP" do
        sign_in(accepter)
        visit_solver_post

        verify_solution_unaccepted_state
        accept_solution
        verify_solution_accepted_state
        verify_solution_quote_content
        verify_solver_and_accepter_info
        expand_solution_quote
      end

      it "accepts and unaccepts post as solution" do
        sign_in(accepter)
        visit_solver_post

        verify_solution_unaccepted_state
        accept_solution
        verify_solution_accepted_state
        verify_solution_info_present

        unaccept_solution
        verify_solution_unaccepted_state
        verify_solution_info_absent
      end
    end
  end

  it "shows the solved post in user activity at /my/activity/solved" do
    Fabricate(:solved_topic, topic:, answer_post: solver_post, accepter:)
    sign_in(solver)
    visit "/my/activity/solved"
    expect(page.find(".post-list")).to have_content(solver_post.cooked)
  end

  private

  def visit_solver_post
    topic_page.visit_topic(topic, post_number: 2)
  end

  def accept_solution
    find(UNACCEPTED_BUTTON_SELECTOR).click
  end

  def unaccept_solution
    find(ACCEPTED_BUTTON_SELECTOR).click
  end

  def verify_solution_accepted_state
    expect(topic_page).to have_css(ACCEPTED_BUTTON_SELECTOR)
    expect(topic_page).to have_css("#{ACCEPTED_ANSWER_QUOTE_SELECTOR}[data-expanded='false']")
  end

  def verify_solution_unaccepted_state
    expect(topic_page).to have_css(UNACCEPTED_BUTTON_SELECTOR)
  end

  def verify_solution_quote_content
    expect(topic_page.find("#{ACCEPTED_ANSWER_QUOTE_SELECTOR} blockquote")).to have_content(
      "The answer is 42",
    )
  end

  def verify_solver_and_accepter_info
    expect(topic_page.find(SOLVER_INFO_SELECTOR)).to have_content("Solved by #{solver.name}")
    expect(topic_page.find(ACCEPTER_INFO_SELECTOR)).to have_content(
      "Marked as solved by #{accepter.name}",
    )
  end

  def verify_solution_info_present
    expect(topic_page).to have_css(ACCEPTED_ANSWER_QUOTE_SELECTOR)
    expect(topic_page).to have_css(SOLVER_INFO_SELECTOR)
    expect(topic_page).to have_css(ACCEPTER_INFO_SELECTOR)
  end

  def verify_solution_info_absent
    expect(topic_page).to have_no_css(ACCEPTED_ANSWER_QUOTE_SELECTOR)
    expect(topic_page).to have_no_css(SOLVER_INFO_SELECTOR)
    expect(topic_page).to have_no_css(ACCEPTER_INFO_SELECTOR)
  end

  def expand_solution_quote
    topic_page.find(QUOTE_TOGGLE_SELECTOR).click
    expect(topic_page).to have_css("#{ACCEPTED_ANSWER_QUOTE_SELECTOR}[data-expanded='true']")
  end
end
