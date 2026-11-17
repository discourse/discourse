# frozen_string_literal: true

RSpec.describe "Creating a post with deeply nested quotes", type: :request do
  fab!(:user) { Fabricate(:user, trust_level: TrustLevel[2]) }
  fab!(:topic) { Fabricate(:topic, user: user) }

  def nested_quotes_raw(depth: 250)
    raw = '<p>hello <span class="mention">@bob</span></p>'
    depth.times { raw = %(<aside class="quote">#{"<i>x</i>" * 12}#{raw}</aside>) }
    raw
  end

  def flat_quotes_raw(depth: 250)
    body = '<p>hello <span class="mention">@bob</span></p>'
    (%(<aside class="quote">#{"<i>x</i>" * 12}</aside>) * depth) + body
  end

  def measure
    started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    yield
    Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at
  end

  it "reads a quote's classes once when stripping many direct-child titles during validation" do
    # One long `group-` token: a multi-class value is dropped by the cooked class
    # allowlist, and the read count only matters for a quote that survives cooking.
    quote_classes = "quote group-#{"x" * 13_800}"
    title_count = 500
    raw =
      %(<aside class="#{quote_classes}">#{'<div class="title">quoted user</div>' * title_count}<p>quoted body</p></aside>)
    expect(raw.length).to be < SiteSetting.max_post_length

    class_reads = []
    # Count only the core pass; plugin strippers may perform their own linear walks.
    allow(PostStripper).to receive(:run_core_strippers).and_wrap_original do |original, fragment|
      quote = fragment.at_css("aside.quote")
      expect(quote["class"]).to eq(quote_classes)
      expect(quote.css(".title").size).to eq(title_count)

      reads = 0
      allow(quote).to receive(:[]).and_wrap_original do |read_attribute, name|
        reads += 1 if name == "class"
        read_attribute.call(name)
      end

      result = original.call(fragment)
      class_reads << reads
      expect(quote.css(".title")).to be_empty
      expect(quote.text).to eq("quoted body")
      result
    end

    sign_in(user)
    post "/posts.json", params: { raw: raw, topic_id: topic.id }

    expect(response.status).to eq(200)
    created_post = Post.find(response.parsed_body["id"])
    cooked = Nokogiri::HTML5.fragment(created_post.cooked)
    expect(cooked.at_css("aside.quote")["class"]).to eq(quote_classes)
    expect(cooked.css(".title").size).to eq(title_count)
    expect(class_reads).not_to be_empty
    expect(class_reads).to all(eq(1))
  end

  it "strips nested quotes in a single pass" do
    raw = nested_quotes_raw(depth: 150)

    # Warm up the lazy paths, including parsing the 150-deep document, so the
    # timed run measures only the walk.
    warmup = Nokogiri::HTML5.fragment(raw)
    expect(warmup.css(".mention").size).to eq(1)
    PostStripper.strip(warmup)
    expect(warmup.css(".mention")).to be_empty

    elapsed = measure { PostStripper.strip(Nokogiri::HTML5.fragment(raw)) }

    # The linear walk takes ~5ms here, up to ~50ms with GC pressure. A quote
    # that rescans its subtree takes over a second at this depth and grows
    # quadratically, so this leaves a wide margin without ever passing a
    # regression that matters.
    expect(elapsed).to be < 0.5
  end

  it "creates a deeply nested quote post through the full request path" do
    raw = nested_quotes_raw

    # same characters and elements, only the quote nesting differs
    expect(raw.length).to eq(flat_quotes_raw.length)
    expect(raw.length).to be < SiteSetting.max_post_length

    sign_in(user)
    post "/posts.json", params: { raw: raw, topic_id: topic.id }

    expect(response.status).to eq(200)
    created_post = Post.find(response.parsed_body["id"])
    cooked = Nokogiri::HTML5.fragment(created_post.cooked)
    expect(cooked.css("aside.quote").size).to eq(250)
    # stripping happens on the analyzer's copy, so the persisted mention stays;
    # what matters is that it was stripped before mention extraction
    expect(created_post.raw_mentions).to be_empty
  end
end
