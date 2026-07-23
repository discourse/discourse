# frozen_string_literal: true

def build_post(user, raw)
  Post.new(user: user, raw: raw)
end

describe DiscoursePostEvent::EventParser do
  subject(:parser) { DiscoursePostEvent::EventParser }

  let(:user) { Fabricate(:user) }

  it "works with no event" do
    events = parser.extract_events(build_post(user, "this could be a nice event"))
    expect(events.length).to eq(0)
  end

  it "finds one event" do
    events = parser.extract_events(build_post(user, '[event start="foo" end="bar"]\n[/event]'))
    expect(events.length).to eq(1)
  end

  it "finds multiple events" do
    post_event = build_post user, <<~TXT
      [event start="2020"]
      [/event]

      [event start="2021"]
      [/event]
    TXT

    events = parser.extract_events(post_event)
    expect(events.length).to eq(2)
  end

  it "parses options" do
    events = parser.extract_events(build_post(user, '[event start="foo" end="bar"]\n[/event]'))
    expect(events[0][:start]).to eq("foo")
    expect(events[0][:end]).to eq("bar")
  end

  it "parses showLocalTime" do
    events =
      parser.extract_events(build_post(user, '[event start="foo" showLocalTime="true"]\n[/event]'))
    expect(events[0][:"show-local-time"]).to eq("true")
  end

  it "parses recurrenceUntil" do
    events =
      parser.extract_events(
        build_post(user, '[event start="foo" recurrenceUntil="2025-06-21 23:59"]\n[/event]'),
      )
    expect(events[0][:"recurrence-until"]).to eq("2025-06-21 23:59")
  end

  it "works with escaped string" do
    events =
      parser.extract_events(
        build_post(user, "I am going to get that fixed.\n\n[event start=\"bar\"]\n[/event]"),
      )
    expect(events[0][:start]).to eq("bar")
  end

  it "parses options where value has spaces" do
    events = parser.extract_events(build_post(user, '[event start="foo" name="bar baz"]\n[/event]'))
    expect(events[0][:name]).to eq("bar baz")
  end

  it "doesn’t parse invalid options" do
    events =
      parser.extract_events(
        build_post(
          user,
          "I am going to get that fixed.\n\n[event start=\"foo\" something=\"bar\"]\n[/event]",
        ),
      )
    expect(events[0][:something]).to be(nil)

    events =
      parser.extract_events(
        build_post(user, "I am going to get that fixed.\n\n[event something=\"bar\"]\n[/event]"),
      )
    expect(events).to eq([])
  end

  it "doesn’t parse an event in codeblock" do
    post_event = build_post user, <<-TXT
      Example event:
      ```
      [event start=\"bar\"]\n[/event]
      ```
    TXT

    events = parser.extract_events(post_event)

    expect(events).to eq([])
  end

  it "doesn’t parse in blockquote" do
    post_event = build_post user, <<-TXT
      [event start="2020"][/event]
    TXT

    events = parser.extract_events(post_event)
    expect(events).to eq([])
  end

  it "doesn’t escape event name" do
    events =
      parser.extract_events(
        build_post(user, '[event start="foo" name="bar <script> baz"]\n[/event]'),
      )
    expect(events[0][:name]).to eq("bar <script> baz")
  end

  it "doesn't escape urls" do
    post_event = build_post user, <<~TXT
        [event start="2020" url="https://example.com/?q=foo&all=true" image="upload://6c4fsAgNM6Npo7raNCPqVm2whzz.jpeg"]
        [/event]
      TXT

    events = parser.extract_events(post_event)
    expect(events[0][:url]).to eq("https://example.com/?q=foo&all=true")
    expect(events[0][:image]).to eq("upload://6c4fsAgNM6Npo7raNCPqVm2whzz.jpeg")
  end

  it "doesn't escape location" do
    post_event = build_post user, <<~TXT
        [event start="2020" location="Joe & Sons (downtown)"]
        [/event]
      TXT

    events = parser.extract_events(post_event)
    expect(events[0][:location]).to eq("Joe & Sons (downtown)")
  end

  it "decodes entities in location so escaped legacy raws self-heal" do
    post_event = build_post user, <<~TXT
        [event start="2020" location="Joe &amp; Sons"]
        [/event]
      TXT

    events = parser.extract_events(post_event)
    expect(events[0][:location]).to eq("Joe & Sons")
  end

  it "extracts description as inline markdown" do
    post_event = build_post user, <<~TXT
      [event start="2020"]
      Check out https://example.com for details
      [/event]
    TXT

    events = parser.extract_events(post_event)
    expect(events[0][:description]).to eq("Check out https://example.com for details")
  end

  it "preserves markdown links, emoji and mentions in the description" do
    post_event = build_post user, <<~TXT
      [event start="2020"]
      See [the agenda](https://agenda.example.com) :tada: with @system
      [/event]
    TXT

    events = parser.extract_events(post_event)
    expect(events[0][:description]).to eq(
      "See [the agenda](https://agenda.example.com) :tada: with @system",
    )
  end

  describe ".cook_inline" do
    it "keeps plain text as plain text" do
      expect(parser.cook_inline("Conference Room A")).to eq("Conference Room A")
    end

    it "renders markdown links" do
      expect(parser.cook_inline("[RSVP](https://zoom.example.com/j/123)")).to eq(
        '<a href="https://zoom.example.com/j/123" rel="noopener nofollow ugc">RSVP</a>',
      )
    end

    it "supports urls with balanced parentheses" do
      result = parser.cook_inline("[Map](https://en.wikipedia.org/wiki/Sting_(musician))")

      expect(Nokogiri::HTML5.fragment(result).at_css("a")["href"]).to eq(
        "https://en.wikipedia.org/wiki/Sting_(musician)",
      )
    end

    it "links bare urls without onebox markup" do
      result = parser.cook_inline("https://www.youtube.com/watch?v=abc")

      link = Nokogiri::HTML5.fragment(result).at_css("a")
      expect(link["href"]).to eq("https://www.youtube.com/watch?v=abc")
      expect(link["class"]).to be_blank
    end

    it "links scheme-less urls" do
      result = parser.cook_inline("zoom.us/j/123")

      expect(Nokogiri::HTML5.fragment(result).at_css("a")["href"]).to eq("http://zoom.us/j/123")
    end

    it "does not render markdown beyond links and emoji" do
      expect(parser.cook_inline("**Room 4** # not a heading")).to eq("**Room 4** # not a heading")
    end

    it "renders emoji" do
      expect(parser.cook_inline("Party :tada:")).to include("images/emoji")
    end

    it "renders newlines as line breaks" do
      expect(parser.cook_inline("line one\nline two")).to eq("line one<br>\nline two")
    end

    it "escapes html" do
      result = parser.cook_inline("<script>alert(1)</script> & <b>Room</b>")

      expect(result).not_to include("<script>")
      expect(result).not_to include("<b>")
      expect(result).to include("&amp;")
    end

    it "rejects non-http link destinations" do
      expect(parser.cook_inline("[click](javascript:alert(1))")).not_to include("href")
    end

    it "omits nofollow for posts that do not require it" do
      staff_user = Fabricate(:admin)
      post = Fabricate(:post, user: staff_user)

      expect(parser.cook_inline("See https://example.com", post: post)).to eq(
        'See <a href="https://example.com">https://example.com</a>',
      )
    end
  end

  describe ".inline_text" do
    it "flattens markdown links to their label" do
      expect(parser.inline_text("[RSVP](https://zoom.example.com) at Joe & Sons :tada:")).to eq(
        "RSVP at Joe & Sons :tada:",
      )
    end
  end

  context "with custom fields" do
    before { SiteSetting.discourse_post_event_allowed_custom_fields = "foo-bar|bar" }

    it "parses allowed custom fields" do
      post_event = build_post user, <<~TXT
        [event start="2020" fooBar="1" bar="2"]
        [/event]
      TXT

      events = parser.extract_events(post_event)
      expect(events[0][:"foo-bar"]).to eq("1")
      expect(events[0][:bar]).to eq("2")
    end

    it "doesn’t parse not allowed custom fields" do
      post_event = build_post user, <<~TXT
        [event start="2020" baz="1"]
        [/event]
      TXT

      events = parser.extract_events(post_event)
      expect(events[0][:baz]).to eq(nil)
    end
  end

  context "with mixed-case custom fields" do
    before do
      SiteSetting.discourse_post_event_allowed_custom_fields =
        "field_aa|fieldbb|field_CC|fieldDD|my.field"
    end

    it "parses fields regardless of case or separators" do
      post_event = build_post user, <<~TXT
        [event start="2020" fieldAa="1" fieldbb="2" fieldCc="3" fielddd="4" myField="5"]
        [/event]
      TXT

      event = parser.extract_events(post_event)[0]

      expect(event[:field_aa]).to eq("1")
      expect(event[:fieldbb]).to eq("2")
      expect(event[:field_CC]).to eq("3")
      expect(event[:fieldDD]).to eq("4")
      expect(event[:"my.field"]).to eq("5")
    end
  end
end
