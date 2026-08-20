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

  let(:topic_page) { PageObjects::Pages::SolvedTopic.new }

  ACCEPTED_ANSWER_SELECTOR = ".accepted-answers .d-post-accordion-item"
  ACCEPTED_ANSWER_CONTENT_SELECTOR = ".d-post-accordion-item__content"
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
    topic_page.visit_solution(topic:, post: solver_post)

    expect(topic_page).to have_unaccepted_solution(solver_post)
    topic_page.accept_solution(solver_post)
    expect(topic_page).to have_accepted_solution(solver_post)
    expect(topic_page).to have_solution_content(solver_post, content: "The answer is 42")
    expect(topic_page).to have_solution_authors(post: solver_post, solver:, accepter:)
    expect(topic_page).to have_expanded_solution_excerpt(solver_post)
    topic_page.toggle_solution_excerpt(solver_post)
    expect(topic_page).to have_collapsed_solution_excerpt(solver_post)
  end

  it "accepts and unaccepts post as solution" do
    sign_in(accepter)
    topic_page.visit_solution(topic:, post: solver_post)

    expect(topic_page).to have_unaccepted_solution(solver_post)
    topic_page.accept_solution(solver_post)
    expect(topic_page).to have_accepted_solution(solver_post)
    expect(topic_page).to have_solution_info

    topic_page.unaccept_solution(solver_post)
    expect(topic_page).to have_unaccepted_solution(solver_post)
    expect(topic_page).to have_no_solution_info
  end

  it "shows the solved post in user activity at /my/activity/solved" do
    solved_topic = Fabricate(:solved_topic, topic:)
    Fabricate(:topic_answer, solved_topic:, post: solver_post, accepter:)
    sign_in(solver)
    visit "/my/activity/solved"
    expect(page.find(".post-list")).to have_content("The answer is 42")
  end

  describe "hidden overflow" do
    fab!(:solved_topic) { Fabricate(:solved_topic, topic:) }
    fab!(:topic_answer) { Fabricate(:topic_answer, solved_topic:, post: solver_post, accepter:) }

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

    expect(topic_page).to have_expanded_solution_excerpt(solver_post)
    topic_page.toggle_solution_excerpt(solver_post)
    expect(topic_page).to have_collapsed_solution_excerpt(solver_post)
    topic_page.toggle_solution_excerpt(solver_post)
    expect(topic_page).to have_expanded_solution_excerpt(solver_post)
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
      topic_page.visit_solution(topic:, post: solver_post)

      expect(topic_page).to have_no_solution_info
      expect(topic_page).to have_unaccepted_solution(solver_post)
      expect(topic_page).to have_unaccepted_solution(solver_post2)

      topic_page.accept_solution(solver_post)

      expect(topic_page).to have_solution_info
      expect(topic_page).to have_accepted_solution(solver_post)
      expect(topic_page).to have_unaccepted_solution(solver_post2)
      expect(topic_page).to have_expanded_solution_excerpt(solver_post)
      expect(topic_page).to have_solution_content(solver_post, content: "The answer is 42")
      expect(topic_page).to have_solution_authors(post: solver_post, solver:, accepter:)

      sign_in(accepter2)
      topic_page.visit_solution(topic:, post: solver_post2)

      expect(topic_page).to have_solution_info
      expect(topic_page).to have_accepted_solution(solver_post)
      expect(topic_page).to have_unaccepted_solution(solver_post2)

      topic_page.accept_solution(solver_post2)

      expect(topic_page).to have_solution_info
      expect(topic_page).to have_accepted_solution(solver_post)
      expect(topic_page).to have_accepted_solution(solver_post2)
      expect(topic_page).to have_expanded_solution_excerpt(solver_post)
      expect(topic_page).to have_collapsed_solution_excerpt(solver_post2)
      expect(topic_page).to have_solution_authors(post: solver_post, solver:, accepter:)
      expect(topic_page).to have_solution_authors(
        post: solver_post2,
        solver: solver2,
        accepter: accepter2,
      )
      expect(topic_page).to have_solution_content(solver_post, content: "The answer is 42")
      expect(topic_page).to have_no_solution_content(solver_post2)
      topic_page.toggle_solution_excerpt(solver_post2)
      expect(topic_page).to have_expanded_solution_excerpt(solver_post2)
      expect(topic_page).to have_solution_content(solver_post2, content: "The answer is over 9000")
    end

    it "correctly updates excerpts when removing one of many accepted solutions" do
      sign_in(accepter)
      topic_page.visit_solution(topic:, post: solver_post)

      expect(topic_page).to have_no_solution_info

      topic_page.accept_solution(solver_post)
      topic_page.accept_solution(solver_post2)

      expect(topic_page).to have_solution_info
      expect(topic_page).to have_accepted_solution(solver_post)
      expect(topic_page).to have_accepted_solution(solver_post2)
      expect(topic_page).to have_expanded_solution_excerpt(solver_post)
      expect(topic_page).to have_collapsed_solution_excerpt(solver_post2)
      expect(topic_page).to have_solution_authors(post: solver_post, solver:, accepter:)
      expect(topic_page).to have_solution_authors(post: solver_post2, solver: solver2, accepter:)
      expect(topic_page).to have_solution_content(solver_post, content: "The answer is 42")
      expect(topic_page).to have_no_solution_content(solver_post2)
      topic_page.toggle_solution_excerpt(solver_post2)
      expect(topic_page).to have_expanded_solution_excerpt(solver_post2)
      expect(topic_page).to have_solution_content(solver_post2, content: "The answer is over 9000")

      topic_page.unaccept_solution(solver_post)

      expect(topic_page).to have_solution_info
      expect(topic_page).to have_unaccepted_solution(solver_post)
      expect(topic_page).to have_accepted_solution(solver_post2)
      expect(topic_page).to have_solution_authors(post: solver_post2, solver: solver2, accepter:)
      expect(topic_page).to have_solution_content(solver_post2, content: "The answer is over 9000")

      topic_page.unaccept_solution(solver_post2)
      expect(topic_page).to have_no_solution_info
    end
  end
end
