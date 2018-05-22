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

    it "doesn't count emoji images" do
      with_emoji = "<p>Hi <img src=\"/images/emoji/twitter/smile.png?v=5\" title=\":smile:\" class=\"emoji\" alt=\":smile:\"></p>"
      arg = ([with_emoji] + paragraphs).join("\n")
      SiteSetting.digest_min_excerpt_length = 50
      expect(helper.email_excerpt(arg)).to eq([with_emoji, paragraphs[0]].join)
    end

    it "only counts link text" do
      with_link = "<p>Hi <a href=\"https://really-long.essays.com/essay/number/9000/this-one-is-about-friends-and-got-a-C-minus-in-grade-9\">friends</a>!</p>"
      arg = ([with_link] + paragraphs).join("\n")
      SiteSetting.digest_min_excerpt_length = 50
      expect(helper.email_excerpt(arg)).to eq([with_link, paragraphs[0]].join)
    end

    it "uses user quotes but not post quotes" do
      cooked = <<~HTML
        <p>BEFORE</p>
        <blockquote>
          <p>This is a user quote</p>
        </blockquote>
        <aside class="quote" data-post="3" data-topic="87369">
          <div class="title">A Title</div>
          <blockquote>
            <p>This is a post quote</p>
          </blockquote>
        </aside>
        <p>AFTER</p>
      HTML

      expect(helper.email_excerpt(cooked)).to eq "<p>BEFORE</p><blockquote>\n  <p>This is a user quote</p>\n</blockquote><p>AFTER</p>"
    end
  end
end
