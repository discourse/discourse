# frozen_string_literal: true

#
RSpec.describe Chat::Message do
  describe ".cook" do
    it "renders kbd inline tag" do
      cooked = Chat::Message.cook <<~MD
    <kbd>Esc</kbd> is pressed
    MD

      expect(cooked).to include("<p><kbd>Esc</kbd> is pressed</p>")
    end

    it "renders details block tag" do
      cooked = Chat::Message.cook <<~MD
    <details>
      <summary>Dog</summary>
      Cat
    </details>
    MD

      expect(cooked).to include(<<~HTML.strip)
        <details><br>
        <summary>Dog</summary><br>
        Cat<br>
        </details>
      HTML
    end
  end
end
