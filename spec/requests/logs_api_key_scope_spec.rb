# frozen_string_literal: true

RSpec.describe "logs:messages API key scope" do
  let(:api_key) do
    Fabricate(
      :api_key,
      api_key_scopes: [Fabricate.build(:api_key_scope, resource: "logs", action: "messages")],
    )
  end

  let(:headers) do
    { "Api-Key" => api_key.key, "Api-Username" => "system", "X-Requested-With" => "XMLHttpRequest" }
  end

  def suppression_patterns
    Logster::SuppressionPattern.find_all(raw: true)
  end

  before { Logster.store.clear }

  after do
    suppression_patterns.each { |pattern| Logster::SuppressionPattern.new(pattern).destroy }
    Logster.store.clear
  end

  it "allows listing and showing log messages" do
    message = Logster.store.report(Logger::Severity::WARN, "test", "a readable message")

    post "/logs/messages.json", headers: headers
    expect(response.status).to eq(200)
    expect(response.parsed_body["messages"].map { |m| m["key"] }).to include(message.key)

    get "/logs/show/#{message.key}.json", headers: headers
    expect(response.status).to eq(200)
    expect(response.parsed_body["message"]).to eq("a readable message")
  end

  it "does not allow changing log messages through a query string ending in .json" do
    message = Logster.store.report(Logger::Severity::WARN, "test", "a message that must survive")

    post "/logs/clear?x=.json", headers: headers
    expect(response.status).to eq(404)

    put "/logs/protect/#{message.key}?x=.json", headers: headers
    expect(response.status).to eq(404)

    put "/logs/solve/#{message.key}?x=.json", headers: headers
    expect(response.status).to eq(404)

    delete "/logs/message/#{message.key}?x=.json", headers: headers
    expect(response.status).to eq(404)

    stored = Logster.store.get(message.key)
    expect(stored).to be_present
    expect(stored.protected).to eq(false)
    expect(Logster.store.count).to eq(1)
  end

  it "does not allow write requests to logster endpoints ending in .json" do
    Logster.store.report(Logger::Severity::WARN, "test", "a message that must survive")

    post "/logs/patterns/suppression.json",
         params: {
           pattern: "/.*/",
           retroactive: true,
         },
         headers: headers
    expect(response.status).to eq(404)

    put "/logs/reset-count.json", headers: headers
    expect(response.status).to eq(404)

    expect(suppression_patterns).to be_empty
    expect(Logster.store.count).to eq(1)
  end
end
