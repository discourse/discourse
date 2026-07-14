# frozen_string_literal: true

describe "Solved" do
  fab!(:admin)
  fab!(:solver, :user)
  fab!(:accepter) { Fabricate(:user, name: "<b>DERP<b>") }
  fab!(:topic) { Fabricate(:post, user: admin).topic }
  fab!(:solver_post) do
    long_cooked =
      "<p>The answer is 42.</p>" + ("<p>Some additional context for the answer.</p>" * 10)
    Fabricate(:post, topic:, user: solver, cooked: long_cooked)
  end

  let(:topic_page) { PageObjects::Pages::Topic.new }

  UNACCEPTED_BUTTON_SELECTOR = ".post-action-menu__solved-unaccepted"
  ACCEPTED_BUTTON_SELECTOR = ".post-action-menu__solved-accepted"
  ACCEPTED_ANSWER_SELECTOR = ".accepted-answers .d-post-accordion-item"
  ACCEPTED_ANSWER_CONTENT_SELECTOR = ".d-post-accordion-item__content"
  SOLVER_SELECTOR = ".d-post-accordion-item__metadata .user-link"
  ACCEPTER_SELECTOR = ".d-post-accordion-item__metadata .accepter-link"
  QUOTE_TOGGLE_SELECTOR = ".d-post-accordion-item__toggle"
  QUOTE_JUMP_SELECTOR = ".d-post-accordion-item__jump"

  before do
    SiteSetting.solved_enabled = true
    SiteSetting.allow_solved_on_all_topics = true
    SiteSetting.accept_all_solutions_allowed_groups = Group::AUTO_GROUPS[:everyone]
    SiteSetting.show_who_marked_solved = true
    SiteSetting.display_name_on_posts = true
  end

  it "accepts post as solution and shows in OP" do
    sign_in(accepter)
    visit_solver_post(2)

    verify_solution_unaccepted_state(2)
    accept_solution(2)
    verify_solution_accepted_state(2)
    verify_solution_content(2, "The answer is 42")
    verify_solver_and_accepter_info(2, solver, accepter)
    verify_solution_excerpt_expanded(2)
    toggle_solution_excerpt(2)
    verify_solution_excerpt_collapsed(2)
  end

  it "accepts and unaccepts post as solution" do
    sign_in(accepter)
    visit_solver_post(2)

    verify_solution_unaccepted_state(2)
    accept_solution(2)
    verify_solution_accepted_state(2)
    verify_solution_info_present

    unaccept_solution(2)
    verify_solution_unaccepted_state(2)
    verify_solution_info_absent
  end

  it "shows the solved post in user activity at /my/activity/solved" do
    solved_topic = Fabricate(:solved_topic, topic:)
    Fabricate(:topic_answer, solved_topic:, post: solver_post, accepter:)
    sign_in(solver)
    visit "/my/activity/solved"
    expect(page.find(".post-list")).to have_content("The answer is 42")
  end

  describe "hidden overflow" do
    before do
      solved_topic = Fabricate(:solved_topic, topic:)
      Fabricate(:topic_answer, solved_topic:, post: solver_post, accepter:)
    end

    describe "when solved_quote_length = 0" do
      before { SiteSetting.solved_quote_length = 0 }

      it "hides content, displays jump button" do
        sign_in(solver)
        topic_page.visit_topic(topic)

        within("#{ACCEPTED_ANSWER_SELECTOR}[data-post='2']") do
          expect(page).not_to have_css(QUOTE_TOGGLE_SELECTOR)
          expect(page).not_to have_css(".d-post-accordion-item__body")
          expect(page).to have_css(QUOTE_JUMP_SELECTOR)
          find(QUOTE_JUMP_SELECTOR).click
        end
      end
    end

    describe "when solved_quote_length is short" do
      before { SiteSetting.solved_quote_length = 1 }

      it "sets the overflowing data element" do
        sign_in(solver)
        topic_page.visit_topic(topic)

        expect(page).to have_css(
          "#{ACCEPTED_ANSWER_SELECTOR}[data-post='2'][data-overflowing='true']",
        )
        expect(page).to have_css(".d-post-accordion-item__body")
      end
    end

    describe "when solved_quote_length is long" do
      before { SiteSetting.solved_quote_length = 99_999_999 }

      it "does not set the overflowing data element" do
        sign_in(solver)
        topic_page.visit_topic(topic)

        expect(page).to have_css(
          "#{ACCEPTED_ANSWER_SELECTOR}[data-post='2'][data-overflowing='false']",
        )
        expect(page).to have_css(".d-post-accordion-item__body")
      end
    end
  end

  it "should collapse/expand the solution when clicking the toggle" do
    solved_topic = Fabricate(:solved_topic, topic:)
    Fabricate(:topic_answer, solved_topic:, post: solver_post, accepter:)

    sign_in(accepter)
    topic_page.visit_topic(topic)

    verify_solution_excerpt_expanded(2)
    toggle_solution_excerpt(2)
    verify_solution_excerpt_collapsed(2)
    toggle_solution_excerpt(2)
    verify_solution_excerpt_expanded(2)
  end

  describe "solution excerpt formatting" do
    it "preserves code blocks in the solution excerpt" do
      raw = <<~RAW
        Here's the solution:

        ```ruby
        def hello
          puts "world"
        end
        ```

        Hope this helps!
      RAW
      code_solution_post = Fabricate(:post, topic:, user: admin, raw:)
      solved_topic = Fabricate(:solved_topic, topic:)
      Fabricate(:topic_answer, solved_topic:, post: code_solution_post, accepter:)
      sign_in(accepter)
      topic_page.visit_topic(topic)

      within(ACCEPTED_ANSWER_CONTENT_SELECTOR) do
        expect(page).to have_css("pre code.lang-ruby")
        expect(page).to have_content("def hello")
        expect(page).to have_content('puts "world"')
      end
    end

    it "preserves images in the solution excerpt" do
      upload = Fabricate(:upload)
      raw = "Check this image: ![test image](#{upload.short_url})"
      image_solution_post = Fabricate(:post, topic:, user: admin, raw:)
      solved_topic = Fabricate(:solved_topic, topic:)
      Fabricate(:topic_answer, solved_topic:, post: image_solution_post, accepter:)

      sign_in(accepter)
      topic_page.visit_topic(topic)

      within(ACCEPTED_ANSWER_CONTENT_SELECTOR) { expect(page).to have_css("img") }
    end
  end

  describe "with multiple solutions enabled" do
    fab!(:solver2, :user)
    fab!(:accepter2, :user)
    fab!(:solver_post2) do
      Fabricate(:post, topic:, user: solver2, cooked: "The answer is over 9000")
    end

    before { SiteSetting.solved_allow_multiple_solutions = true }

    it "accepts two posts as solutions and shows in OP" do
      sign_in(accepter)
      visit_solver_post(2)

      verify_solution_info_absent
      verify_solution_unaccepted_state(2)
      verify_solution_unaccepted_state(3)

      accept_solution(2)

      verify_solution_info_present
      verify_solution_accepted_state(2)
      verify_solution_unaccepted_state(3)
      verify_solution_excerpt_expanded(2)
      verify_solution_content(2, "The answer is 42")
      verify_solver_and_accepter_info(2, solver, accepter)

      sign_in(accepter2)
      visit_solver_post(3)

      verify_solution_info_present
      verify_solution_accepted_state(2)
      verify_solution_unaccepted_state(3)

      accept_solution(3)

      verify_solution_info_present
      verify_solution_accepted_state(2)
      verify_solution_accepted_state(3)
      verify_solution_excerpt_expanded(2)
      verify_solution_excerpt_collapsed(3)
      verify_solver_and_accepter_info(2, solver, accepter)
      verify_solver_and_accepter_info(3, solver2, accepter2)
      verify_solution_content(2, "The answer is 42")
      verify_solution_content_missing(3)
      toggle_solution_excerpt(3)
      verify_solution_excerpt_expanded(3)
      verify_solution_content(3, "The answer is over 9000")
    end

    it "correctly updates excerpts when removing one of many accepted solutions" do
      sign_in(accepter)
      visit_solver_post(2)

      verify_solution_info_absent

      accept_solution(2)
      accept_solution(3)

      verify_solution_info_present
      verify_solution_accepted_state(2)
      verify_solution_accepted_state(3)
      verify_solution_excerpt_expanded(2)
      verify_solution_excerpt_collapsed(3)
      verify_solver_and_accepter_info(2, solver, accepter)
      verify_solver_and_accepter_info(3, solver2, accepter)
      verify_solution_content(2, "The answer is 42")
      verify_solution_content_missing(3)
      toggle_solution_excerpt(3)
      verify_solution_excerpt_expanded(3)
      verify_solution_content(3, "The answer is over 9000")

      unaccept_solution(2)

      verify_solution_info_present
      verify_solution_unaccepted_state(2)
      verify_solution_accepted_state(3)
      verify_solver_and_accepter_info(3, solver2, accepter)
      verify_solution_content(3, "The answer is over 9000")

      unaccept_solution(3)
      verify_solution_info_absent
    end
  end

  private

  def visit_solver_post(post_number)
    topic_page.visit_topic(topic, post_number:)
  end

  def accept_solution(post_number)
    within("article#post_#{post_number}") { find(UNACCEPTED_BUTTON_SELECTOR).click }
  end

  def unaccept_solution(post_number)
    within("article#post_#{post_number}") { find(ACCEPTED_BUTTON_SELECTOR).click }
  end

  def verify_solution_accepted_state(post_number)
    within("article#post_#{post_number}") do
      expect(topic_page).to have_css(ACCEPTED_BUTTON_SELECTOR)
    end

    expect(topic_page).to have_css("#{ACCEPTED_ANSWER_SELECTOR}[data-post='#{post_number}']")
  end

  def verify_solution_unaccepted_state(post_number)
    within("article#post_#{post_number}") do
      expect(topic_page).to have_css(UNACCEPTED_BUTTON_SELECTOR)
    end
  end

  def verify_solution_content(post_number, content)
    within("#{ACCEPTED_ANSWER_SELECTOR}[data-post='#{post_number}']") do
      expect(find(ACCEPTED_ANSWER_CONTENT_SELECTOR)).to have_content(content)
    end
  end

  def verify_solution_content_missing(post_number)
    within("#{ACCEPTED_ANSWER_SELECTOR}[data-post='#{post_number}']") do
      expect(page).not_to have_css(ACCEPTED_ANSWER_CONTENT_SELECTOR)
    end
  end

  def verify_solver_and_accepter_info(post_number, solver, accepter)
    within("#{ACCEPTED_ANSWER_SELECTOR}[data-post='#{post_number}']") do
      expect(find(SOLVER_SELECTOR)).to have_content(solver.username)
      expect(find(ACCEPTER_SELECTOR)).to have_content(accepter.username)
    end
  end

  def verify_solution_info_present
    expect(topic_page).to have_css(ACCEPTED_ANSWER_SELECTOR)
    expect(topic_page).to have_css(SOLVER_SELECTOR)
    expect(topic_page).to have_css(ACCEPTER_SELECTOR)
  end

  def verify_solution_info_absent
    expect(topic_page).to have_no_css(ACCEPTED_ANSWER_SELECTOR)
    expect(topic_page).to have_no_css(SOLVER_SELECTOR)
    expect(topic_page).to have_no_css(ACCEPTER_SELECTOR)
  end

  def toggle_solution_excerpt(post_number)
    within("#{ACCEPTED_ANSWER_SELECTOR}[data-post='#{post_number}']") do
      find(QUOTE_TOGGLE_SELECTOR).click
    end
  end

  def verify_solution_excerpt_expanded(post_number)
    expect(topic_page).to have_css(
      "#{ACCEPTED_ANSWER_SELECTOR}[data-post='#{post_number}'][data-expanded]",
    )
  end

  def verify_solution_excerpt_collapsed(post_number)
    expect(topic_page).to have_css(
      "#{ACCEPTED_ANSWER_SELECTOR}[data-post='#{post_number}']:not([data-expanded])",
    )
  end
end
