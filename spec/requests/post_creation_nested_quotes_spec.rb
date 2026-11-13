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
