# frozen_string_literal: true

describe "Discourse Math - KaTeX Link Handling", type: :system do
  let(:user) { Fabricate(:admin) }
  let(:topic) { Fabricate(:topic) }

  before do
    SiteSetting.discourse_math_enabled = true
    SiteSetting.discourse_math_provider = "katex"
    sign_in(user)
  end

  describe "href command behavior" do
    it "processes HTTPS links correctly" do
      raw = "Safe link: $ \\href{https://discourse.org}{Click me} $"

      post = Fabricate(:post, topic: topic, raw: raw, user: user)
      visit "/t/#{topic.slug}/#{topic.id}"

      expect(find("[data-post-id='#{post.id}'] .cooked")).to have_css(
        "a[href='https://discourse.org']",
      )
    end

    it "handles javascript protocols safely" do
      raw = "Script attempt: $ \\href{javascript:window.jsTest=true;alert('XSS')}{Click me} $"

      post = Fabricate(:post, topic: topic, raw: raw, user: user)
      visit "/t/#{topic.slug}/#{topic.id}"

      expect(find("[data-post-id='#{post.id}'] .cooked")).not_to have_css("a[href*='javascript:']")
    end

    it "handles data protocols safely" do
      raw =
        "Data attempt: $ \\href{data:text/html,<script>window.dataTest=true</script>}{Click me} $"

      post = Fabricate(:post, topic: topic, raw: raw, user: user)
      visit "/t/#{topic.slug}/#{topic.id}"

      expect(find("[data-post-id='#{post.id}'] .cooked")).not_to have_css("a[href*='data:']")
    end
  end
end
