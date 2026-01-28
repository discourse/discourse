# frozen_string_literal: true

describe "Post selection | Copy quote", type: :system do
  let(:topic_page) { PageObjects::Pages::Topic.new }
  let(:composer) { PageObjects::Components::Composer.new }
  let(:cdp) { PageObjects::CDP.new }

  fab!(:topic)
  fab!(:post) { Fabricate(:post, topic: topic, raw: "Hello world it's time for quoting!") }
  fab!(:current_user, :admin)

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

    it "preserves list formatting when quoting with mid-text selection" do
      post.update!(raw: "- bullet\n   1. nested ol\n\n1. first\n   1. nested")
      post.rebake!

      topic_page.visit_topic(topic)

      page.execute_script(<<~JS)
        (function() {
          function findTextNode(element) {
            for (let i = 0; i < element.childNodes.length; i++) {
              const node = element.childNodes[i];
              if (node.nodeType === Node.TEXT_NODE && node.textContent.trim()) {
                return node;
              }
            }
            return element;
          }

          function getNodeEndOffset(node) {
            if (node.nodeType === Node.TEXT_NODE) {
              return node.textContent.length;
            }
            return node.childNodes.length;
          }

          const cooked = document.querySelector("#{topic_page.post_by_number_selector(1)} .cooked");
          const firstLi = cooked.querySelector("ul > li");
          const lastLi = cooked.querySelector("ol ol li");
          const startNode = findTextNode(firstLi);
          const endNode = findTextNode(lastLi);

          const selection = window.getSelection();
          const range = document.createRange();
          range.setStart(startNode, 0);
          range.setEnd(endNode, getNodeEndOffset(endNode));
          selection.removeAllRanges();
          selection.addRange(range);
        })();
      JS

      topic_page.copy_quote_button.click

      clipboard_text = cdp.read_clipboard
      expect(clipboard_text).to include("* bullet")
      expect(clipboard_text).to match(/1\.\s*nested ol/)
      expect(clipboard_text).to match(/1\.\s*first/)
      expect(clipboard_text).to match(/1\.\s*nested/)
    end

    it "quotes tight lists without extra blank lines" do
      post.update!(raw: "1. List item 1\n2. List item 2\n3. List item 3")
      post.rebake!

      topic_page.visit_topic(topic)

      page.execute_script(<<~JS)
        (function() {
          const cooked = document.querySelector("#{topic_page.post_by_number_selector(1)} .cooked");
          const listItems = cooked.querySelectorAll("ol > li");
          const firstLi = listItems[0];
          const lastLi = listItems[listItems.length - 1];

          const selection = window.getSelection();
          const range = document.createRange();
          range.selectNodeContents(firstLi);
          range.setEnd(lastLi, lastLi.childNodes.length);
          selection.removeAllRanges();
          selection.addRange(range);
        })();
      JS

      topic_page.copy_quote_button.click

      clipboard_text = cdp.read_clipboard
      expect(clipboard_text).not_to include("1.\n\n")
      expect(clipboard_text).to include("1. List item 1\n2. List item 2")
    end

    it "quotes loose lists with blank lines between items" do
      # Loose list: items separated by blank lines in markdown source
      post.update!(raw: "1. List item 1\n\n2. List item 2\n\n3. List item 3")
      post.rebake!

      topic_page.visit_topic(topic)

      page.execute_script(<<~JS)
        (function() {
          const cooked = document.querySelector("#{topic_page.post_by_number_selector(1)} .cooked");
          const listItems = cooked.querySelectorAll("ol > li");
          const firstLi = listItems[0];
          const lastLi = listItems[listItems.length - 1];

          const selection = window.getSelection();
          const range = document.createRange();
          range.selectNodeContents(firstLi);
          range.setEnd(lastLi, lastLi.childNodes.length);
          selection.removeAllRanges();
          selection.addRange(range);
        })();
      JS

      topic_page.copy_quote_button.click

      clipboard_text = cdp.read_clipboard
      expect(clipboard_text).to include("1. List item 1\n\n2. List item 2")
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
