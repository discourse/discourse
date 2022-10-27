# frozen_string_literal: true

require "rails_helper"

describe Chat::SlackCompatibility do
  describe "#process_text" do
    it "converts mrkdwn links to regular markdown" do
      text = described_class.process_text("this is some text <https://discourse.org>")
      expect(text).to eq("this is some text https://discourse.org")
    end

    it "converts mrkdwn links with titles to regular markdown" do
      text =
        described_class.process_text("this is some text <https://discourse.org|Discourse Forums>")
      expect(text).to eq("this is some text [Discourse Forums](https://discourse.org)")
    end

    it "handles multiple links" do
      text =
        described_class.process_text(
          "this is some text <https://discourse.org|Discourse Forums> with a second link to <https://discourse.org/team>",
        )
      expect(text).to eq(
        "this is some text [Discourse Forums](https://discourse.org) with a second link to https://discourse.org/team",
      )
    end

    it "converts <!here> and <!all> to our mention format" do
      text = described_class.process_text("<!here> this is some important stuff <!all>")
      expect(text).to eq("@here this is some important stuff @all")
    end
  end
end
