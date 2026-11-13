# frozen_string_literal: true

RSpec.describe PostStripper do
  before { SiteSetting.chat_enabled = true }

  it "strips only descendant mentions in chat transcripts" do
    fragment = Nokogiri::HTML5.fragment(<<~HTML)
      <p><a class="mention">@outside_before</a></p>
      <div class="chat-transcript chat-transcript-chained">
        <p><a class="mention other">@inside</a></p>
        <details class="chat-transcript"><div><a class="mention">@nested</a></div></details>
        <a class="mention-group">@group</a>
      </div>
      <p><a class="mention">@outside_after</a></p>
      <div class="chat-transcript-like"><a class="mention">@unrelated</a></div>
      <div class="chat-transcript mention">@container</div>
    HTML

    described_class.strip(fragment)

    expect(fragment.css(".mention").map(&:text)).to contain_exactly(
      "@outside_before",
      "@outside_after",
      "@unrelated",
      "@container",
    )
    expect(fragment.at_css(".mention-group").text).to eq("@group")
    expect(fragment.css(".chat-transcript").size).to eq(3)
  end

  it "does not strip transcript mentions when chat is disabled" do
    SiteSetting.chat_enabled = false
    fragment = Nokogiri::HTML5.fragment(<<~HTML)
      <div class="chat-transcript"><a class="mention">@inside</a></div>
    HTML

    described_class.strip(fragment)

    expect(fragment.at_css(".mention").text).to eq("@inside")
  end
end
