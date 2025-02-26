# frozen_string_literal: true

RSpec.describe Middleware::CrawlerSearch do
  def env(opts = {})
    path = opts.delete(:path) || "/search"
    create_request_env(path: path).merge(
      "HTTP_HOST" => "http://test.com",
      "HTTP_USER_AGENT" => "Googlebot/2.1 (+http://www.googlebot.com/bot.html)",
      "QUERY_STRING" => "q=tell+me+your+secrets",
      "REQUEST_METHOD" => "GET",
      "rack.input" => StringIO.new,
    ).merge(opts)
  end

  describe "call" do
    it "should return a noindex page for crawlers" do
      middleware = Middleware::CrawlerSearch.new(->(env) { [200, {}, [""]] })
      status, headers, response = middleware.call(env)
      puts env.inspect

      expect(status).to eq(200)
      expect(headers).to eq({ "Content-Type" => "text/html", "X-Robots-Tag" => "noindex" })
      expect(response.first).to include("<meta name='robots' content='noindex'>")
    end

    it "should not return a noindex page for non-crawlers" do
      middleware = Middleware::CrawlerSearch.new(->(env) { [200, {}, [""]] })
      status, headers, response =
        middleware.call(
          env(
            {
              "HTTP_USER_AGENT" =>
                "Mozilla/5.0 (Windows NT 6.2; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/32.0.1667.0 Safari/537.36",
            },
          ),
        )

      expect(status).to eq(200)
      expect(headers).to eq({})
      expect(response.first).to eq("")
    end
  end
end
