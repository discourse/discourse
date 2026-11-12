# frozen_string_literal: true

describe "Reading a long inline footnote" do
  fab!(:user)
  fab!(:post) do
    paragraphs = (1..10).map { |number| "    Paragraph #{number}. #{"word " * 60}" }.join("\n\n")

    Fabricate(:post, raw: <<~MARKDOWN)
      A footnote with a lot of content[^1]

      [^1]: Start of the footnote.

      #{paragraphs}

          End of the footnote.
    MARKDOWN
  end

  let(:topic_page) { PageObjects::Pages::Topic.new }
  let(:footnote) { PageObjects::Components::InlineFootnote.new }

  before { sign_in(user) }

  it "lets the user read a long footnote without the popup running off a narrow screen",
     mobile: true do
    resize_window(width: 320) do
      topic_page.visit_topic(post.topic)

      footnote.open

      expect(footnote).to be_within_screen
      expect(footnote).to have_no_horizontal_page_scroll
      expect(footnote).to be_scrollable

      footnote.scroll_to_bottom

      expect(footnote).to have_scrolled_to("End of the footnote.")
    end
  end
end
