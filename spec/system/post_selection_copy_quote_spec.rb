# frozen_string_literal: true

describe "Post selection | Copy quote", type: :system do
  let(:topic_page) { PageObjects::Pages::Topic.new }
  let(:composer) { PageObjects::Components::Composer.new }
  let(:cdp) { PageObjects::CDP.new }

  fab!(:topic)
  fab!(:post) { Fabricate(:post, topic: topic, raw: "Hello world it's time for quoting!") }
  fab!(:current_user, :admin)

  def select_list_items(post_selector, start_li_index, end_li_index)
    js = <<-JS
      const cooked = document.querySelector(arguments[0]);
      const listItems = cooked.querySelectorAll('li');
      const startLi = listItems[arguments[1]];
      const endLi = listItems[arguments[2]];

      // Find the first text node in the li (handles both tight and loose lists)
      function findTextNode(element) {
        if (element.nodeType === Node.TEXT_NODE && element.textContent.trim()) {
          return element;
        }
        for (const child of element.childNodes) {
          const found = findTextNode(child);
          if (found) return found;
        }
        return null;
      }

      const startNode = findTextNode(startLi);
      const endNode = findTextNode(endLi);

      const selection = window.getSelection();
      const range = document.createRange();
      range.setStart(startNode, 0);
      range.setEnd(endNode, endNode.textContent.length);
      selection.removeAllRanges();
      selection.addRange(range);
    JS

    page.execute_script(js, post_selector, start_li_index, end_li_index)
  end

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

    it "resets the quote state when the toolbar is hidden" do
      topic_page.visit_topic(topic)
      select_text_range("#{topic_page.post_by_number_selector(1)} .cooked p", 0, 10)

      expect(page).to have_css(topic_page.copy_quote_button_selector)

      select_text_range(".topic-map__stat-label", 0, 1) # select non cooked content
      topic_page.click_reply_button

      expect(composer).to have_value("")
    end

    it "preserves list formatting when quoting various list types" do
      # Post with multiple list types:
      # - Loose list (items 0-1): has blank lines between items
      # - Tight list (items 2-3): no blank lines
      # - Nested list with custom start (items 4-7): 100. with nested tight bullet list
      list_post = Fabricate(:post, topic: topic, raw: <<~MD, user: current_user)
            Loose list:

            1. First loose

            2. Second loose

            Tight list:

            1. First tight
            2. Second tight

            Nested with start:

            100. Hundred
            101. Hundred one
                 - nested hello
                 - nested world
          MD

      topic_page.visit_topic(topic)
      post_selector = "#{topic_page.post_by_number_selector(list_post.post_number)} .cooked"

      # Test 1: Loose list stays loose (items 0-1)
      select_list_items(post_selector, 0, 1)
      topic_page.copy_quote_button.click
      cdp.clipboard_has_text?("1. First loose\n\n2. Second loose", strict: false)

      # Test 2: Tight list stays tight (items 2-3)
      select_list_items(post_selector, 2, 3)
      topic_page.copy_quote_button.click
      cdp.clipboard_has_text?("1. First tight\n2. Second tight", strict: false)

      # Test 3: Nested list preserves start number (items 4-5 are 100, 101)
      select_list_items(post_selector, 4, 5)
      topic_page.copy_quote_button.click
      cdp.clipboard_has_text?("100. Hundred\n101. Hundred one", strict: false)

      # Test 4: Nested tight bullet list stays tight (items 6-7)
      select_list_items(post_selector, 6, 7)
      topic_page.copy_quote_button.click
      cdp.clipboard_has_text?("* nested hello\n* nested world", strict: false)
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
