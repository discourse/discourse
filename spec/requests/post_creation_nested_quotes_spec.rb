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
    quote_classes = "quote group-#{(["x"] * 2_000).join(" ")}"
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

  it "costs the same whether or not the quotes are nested" do
    flat_raw = flat_quotes_raw
    nested_raw = nested_quotes_raw

    # same characters and elements, only the quote nesting differs
    expect(flat_raw.length).to eq(nested_raw.length)
    expect(nested_raw.length).to be < SiteSetting.max_post_length

    sign_in(user)

    # the cooking pipeline is initialized on first use, keep that out of the timing
    post "/posts.json", params: { raw: "warm up the cooking pipeline", topic_id: topic.id }
    expect(response.status).to eq(200)

    flat_elapsed =
      measure do
        post "/posts.json", params: { raw: flat_raw, topic_id: topic.id }
        expect(response.status).to eq(200)
      end

    nested_elapsed =
      measure do
        post "/posts.json", params: { raw: nested_raw, topic_id: topic.id }
        expect(response.status).to eq(200)
      end

    expect(nested_elapsed).to be < flat_elapsed * 2
  end
end
