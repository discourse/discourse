# frozen_string_literal: true

describe "Post selection | Copy quote", type: :system do
  let(:topic_page) { PageObjects::Pages::Topic.new }
  let(:cdp) { PageObjects::CDP.new }

  fab!(:topic)
  fab!(:post) { Fabricate(:post, topic: topic, raw: "Hello world it's time for quoting!") }
  fab!(:current_user) { Fabricate(:admin) }

  context "when logged in" do
    before do
      sign_in(current_user)
      cdp.allow_clipboard
    end

    it "copies the selection from the post the clipboard" do
      topic_page.visit_topic(topic)

      select_text_range("#{topic_page.post_by_number_selector(1)} .cooked p", 0, 10)
      topic_page.copy_quote_button.click

      cdp.clipboard_has_text?(<<~QUOTE.chomp, chomp: true)
    [quote=\"#{post.user.username}, post:1, topic:#{topic.id}\"]\nHello worl\n[/quote]\n
    QUOTE
    end

    it "does not show the copy quote button if quoting has been disabled by the user" do
      current_user.user_option.update!(enable_quoting: false)
      topic_page.visit_topic(topic)

      select_text_range("#{topic_page.post_by_number_selector(1)} .cooked p", 0, 10)
      expect(page).not_to have_css(topic_page.copy_quote_button_selector)
    end
  end

  context "when anon" do
    it "does not show the copy quote button to anon users" do
      topic_page.visit_topic(topic)

      select_text_range("#{topic_page.post_by_number_selector(1)} .cooked p", 0, 10)
      expect(page).not_to have_css(topic_page.copy_quote_button_selector)
    end
  end
end
