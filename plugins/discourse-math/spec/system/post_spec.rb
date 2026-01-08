# frozen_string_literal: true

RSpec.describe "Discourse Math - post", type: :system do
  fab!(:current_user, :admin)

  before do
    SiteSetting.discourse_math_enabled = true
    sign_in(current_user)
  end

  describe "MathJax provider" do
    before { SiteSetting.discourse_math_provider = "mathjax" }

    it "renders inline math" do
      post = create_post(user: current_user, raw: "The equation $x^2 + y^2 = z^2$ is famous.")
      visit(post.topic.url)

      expect(page).to have_css("#post_1 .math-container.inline-math mjx-container")
    end

    it "renders block math" do
      post =
        create_post(
          user: current_user,
          raw: "Here is a formula:\n\n$$\nx = \\frac{-b \\pm \\sqrt{b^2-4ac}}{2a}\n$$",
        )
      visit(post.topic.url)

      expect(page).to have_css("#post_1 .math-container.block-math mjx-container")
    end

    it "renders math inside details" do
      post =
        create_post(
          user: current_user,
          raw: "This is maths:\n\n[details='math']\n$E=mc^2$\n[/details]",
        )
      visit(post.topic.url)

      find("#post_1 details").click

      expect(page).to have_css(".mathjax-math mjx-container", visible: :all)
    end
  end

  describe "KaTeX provider" do
    before { SiteSetting.discourse_math_provider = "katex" }

    it "renders inline math" do
      post = create_post(user: current_user, raw: "The equation $x^2 + y^2 = z^2$ is famous.")
      visit(post.topic.url)

      expect(page).to have_css("#post_1 .math-container.inline-math .katex")
    end

    it "renders block math" do
      post =
        create_post(user: current_user, raw: "Here is a formula:\n\n$$\nx = \\frac{-b}{2a}\n$$")
      visit(post.topic.url)

      expect(page).to have_css("#post_1 .math-container.block-math .katex")
    end
  end
end
