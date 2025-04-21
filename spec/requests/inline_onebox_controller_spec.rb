# frozen_string_literal: true

RSpec.describe InlineOneboxController do
  it "requires the user to be logged in" do
    get "/inline-onebox.json", params: { urls: [] }
    expect(response.status).to eq(403)
  end

  context "when logged in" do
    fab!(:user)
    before { sign_in(user) }

    it "returns empty JSON for empty input" do
      get "/inline-onebox.json", params: { urls: [] }
      expect(response.status).to eq(200)
      json = response.parsed_body
      expect(json["inline-oneboxes"]).to eq([])
    end

    it "returns a 413 error if more than 10 urls are sent" do
      get "/inline-onebox.json", params: { urls: ("a".."k").to_a }
      expect(response.status).to eq(413)
      json = response.parsed_body
      expect(json["errors"]).to include(I18n.t("inline_oneboxer.too_many_urls"))
    end

    it "returns a 429 error for concurrent requests from the same user" do
      blocked = true
      reached = false

      stub_request(:get, "http://example.com/url-1").to_return do |request|
        reached = true
        sleep 0.001 while blocked
        { status: 200, body: <<~HTML }
          <html>
            <head>
              <title>
                Concurrent inline-oneboxing test
              </title>
            </head>
            <body></body>
          </html>
        HTML
      end

      t1 = Thread.new { get "/inline-onebox.json", params: { urls: ["http://example.com/url-1"] } }

      sleep 0.001 while !reached

      get "/inline-onebox.json", params: { urls: ["http://example.com/url-2"] }
      expect(response.status).to eq(429)
      expect(response.parsed_body["errors"]).to include(
        I18n.t("inline_oneboxer.concurrency_not_allowed"),
      )

      blocked = false
      t1.join
      expect(response.status).to eq(200)
      json = response.parsed_body
      expect(json["inline-oneboxes"].size).to eq(1)
      expect(json["inline-oneboxes"][0]["title"]).to eq("Concurrent inline-oneboxing test")
    end

    it "allows concurrent requests from different users" do
      another_user = Fabricate(:user)

      blocked = true
      reached = false

      stub_request(:get, "http://example.com/url-1").to_return do |request|
        reached = true
        sleep 0.001 while blocked
        { status: 200, body: <<~HTML }
          <html>
            <head>
              <title>
                Concurrent inline-oneboxing test
              </title>
            </head>
            <body></body>
          </html>
        HTML
      end

      stub_request(:get, "http://example.com/url-2").to_return do |request|
        { status: 200, body: <<~HTML }
          <html>
            <head>
              <title>
                Concurrent inline-oneboxing test 2
              </title>
            </head>
            <body></body>
          </html>
        HTML
      end

      t1 =
        Thread.new do
          sign_in(user)
          get "/inline-onebox.json", params: { urls: ["http://example.com/url-1"] }
        end

      sleep 0.001 while !reached

      sign_in(another_user)
      get "/inline-onebox.json", params: { urls: ["http://example.com/url-2"] }
      expect(response.status).to eq(200)
      json = response.parsed_body
      expect(json["inline-oneboxes"].size).to eq(1)
      expect(json["inline-oneboxes"][0]["title"]).to eq("Concurrent inline-oneboxing test 2")

      blocked = false
      t1.join
      expect(response.status).to eq(200)
      json = response.parsed_body
      expect(json["inline-oneboxes"].size).to eq(1)
      expect(json["inline-oneboxes"][0]["title"]).to eq("Concurrent inline-oneboxing test")
    end

    context "with topic link" do
      fab!(:topic)

      it "returns information for a valid link" do
        get "/inline-onebox.json", params: { urls: [topic.url] }
        expect(response.status).to eq(200)
        json = response.parsed_body
        onebox = json["inline-oneboxes"][0]

        expect(onebox).to be_present
        expect(onebox["url"]).to eq(topic.url)
        expect(onebox["title"]).to eq(topic.title)
      end
    end
  end
end
