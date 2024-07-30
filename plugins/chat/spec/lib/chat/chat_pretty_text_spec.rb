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
  end
end
