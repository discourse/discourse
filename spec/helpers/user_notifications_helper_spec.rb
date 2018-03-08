require 'rails_helper'

describe UserNotificationsHelper do
  describe 'email_excerpt' do
    let(:paragraphs) { [
      "<p>This is the first paragraph, but you should read more.</p>",
      "<p>And here is its friend, the second paragraph.</p>"
    ] }

    let(:cooked) do
      paragraphs.join("\n")
    end

    it "can return the first paragraph" do
      SiteSetting.digest_min_excerpt_length = 50
      expect(helper.email_excerpt(cooked)).to eq(paragraphs[0])
    end

    it "can return another paragraph to satisfy digest_min_excerpt_length" do
      SiteSetting.digest_min_excerpt_length = 100
      expect(helper.email_excerpt(cooked)).to eq(paragraphs.join)
    end
  end
end
