# frozen_string_literal: true

RSpec.describe PostStripper do
  it "strips mentions in quotes" do
    mention = '<a class="mention">@andrei</a>'
    cooked = "<aside class='quote'>#{mention}</aside>"
    fragment = Nokogiri::HTML5.fragment(cooked)

    PostStripper.strip(fragment)

    expect(fragment.to_s).to_not include(mention)
  end

  it "strips group mentions in quotes" do
    group_mention = '<a class="mention-group">@moderators</a>'
    cooked = "<aside class='quote'>#{group_mention}</aside>"
    fragment = Nokogiri::HTML5.fragment(cooked)

    PostStripper.strip(fragment)

    expect(fragment.to_s).to_not include(group_mention)
  end

  it "strips oneboxes" do
    onebox =
      '<aside class="onebox">
        Onebox content
      </aside>'
    cooked = "<p>#{onebox}</p>"
    fragment = Nokogiri::HTML5.fragment(cooked)

    PostStripper.strip(fragment)

    expect(fragment.to_s).to_not include(onebox)
  end

  it "strips mentions nested in nested quotes" do
    mention = '<a class="mention">@andrei</a>'
    cooked = "<aside class='quote'><aside class='quote'>#{mention}</aside></aside>"
    fragment = Nokogiri::HTML5.fragment(cooked)

    PostStripper.strip(fragment)

    expect(fragment.to_s).to_not include(mention)
  end

  it "strips quote titles but keeps other titles" do
    cooked = <<~HTML
      <div class="title">outside</div>
      <aside class="quote">
        <div class="title">quoted user</div>
        <blockquote>
          <div class="title">kept</div>
          <aside class="quote"><div class="title">nested quoted user</div><p>nested body</p></aside>
        </blockquote>
      </aside>
      <div class="quote"><div class="title">not an aside</div></div>
      <aside><div class="title">not a quote</div></aside>
    HTML
    fragment = Nokogiri::HTML5.fragment(cooked)

    PostStripper.strip(fragment)

    expect(fragment.at_css("aside.quote > .title")).to be_nil
    expect(fragment.css(".title").map(&:text)).to contain_exactly(
      "outside",
      "kept",
      "not an aside",
      "not a quote",
    )
    expect(fragment.at_css("blockquote p").text).to eq("nested body")
  end

  it "keeps mentions outside of quotes and pre" do
    mention = '<a class="mention">@andrei</a>'
    cooked = "<p>#{mention}</p><aside class='quote'><p>quoted</p></aside>"
    fragment = Nokogiri::HTML5.fragment(cooked)

    PostStripper.strip(fragment)

    expect(fragment.to_s).to include(mention)
  end

  it "strips mentions in pre" do
    mention = '<a class="mention">@andrei</a>'
    cooked = "<pre><code>#{mention}</code></pre>"
    fragment = Nokogiri::HTML5.fragment(cooked)

    PostStripper.strip(fragment)

    expect(fragment.to_s).to_not include(mention)
  end

  it "strips elided content" do
    elided = "<div class='elided'><p>elided</p></div>"
    fragment = Nokogiri::HTML5.fragment("<p>kept</p>#{elided}")

    PostStripper.strip(fragment)

    expect(fragment.to_s).to_not include(elided)
    expect(fragment.to_s).to include("kept")
  end

  it "strips deeply nested quotes without re-scanning every quote" do
    mention = '<a class="mention">@andrei</a>'
    filler = "<i>x</i>" * 12
    cooked = "<p>#{mention}</p>"
    250.times { cooked = "<aside class='quote'>#{filler}#{cooked}</aside>" }
    fragment = Nokogiri::HTML5.fragment(cooked)

    elapsed = Benchmark.realtime { PostStripper.strip(fragment) }

    expect(fragment.to_s).to_not include(mention)
    expect(elapsed).to be < 0.2
  end

  context "with plugins" do
    before { DiscoursePluginRegistry.stubs(:_raw_post_strippers).returns([]) }

    it "runs strippers registered by plugins" do
      plugin_element = '<div class="plugin_class"></div>'

      block = Proc.new { |nokogiri_fragment| nokogiri_fragment.css(".plugin_class").remove }
      plugin = OpenStruct.new(enabled?: true)
      DiscoursePluginRegistry.register_post_stripper({ block: block }, plugin)

      fragment = Nokogiri::HTML5.fragment("<p>#{plugin_element}</p>")

      PostStripper.strip(fragment)

      expect(fragment.to_s).to_not include(plugin_element)
    end
  end
end
