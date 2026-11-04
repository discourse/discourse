# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::NodeErrorHandling do
  subject(:handler) { Class.new { include DiscourseWorkflows::NodeErrorHandling }.new }

  it "keeps the location out of the error's summary", :aggregate_failures do
    expect {
      handler.send(
        :raise_node_error!,
        "Boom",
        description: "details",
        item_index: 2,
        line_number: 4,
      )
    }.to raise_error(DiscourseWorkflows::NodeError) { |error|
      expect(error.message).to eq("Boom [line 4, for item 2]: details")
      expect(error.summary).to eq("Boom: details")
    }
  end

  it "sanitizes explicitly rich errors without changing their plain message or summary" do
    html =
      '<strong onclick="alert(1)">Failure</strong><br><em>Try</em> <code>again</code>' \
        '<a href="/admin" title="Settings" target="_blank">Settings</a>' \
        '<a href="https://example.com">Help</a><a href="http://example.com">Docs</a>' \
        '<a href="javascript:alert(1)">Unsafe</a><a href="data:text/html,evil">Data</a>' \
        '<img src="x" onerror="alert(1)"><script>alert(1)</script><style>body { color: red }</style>'

    expect {
      handler.send(:raise_node_error!, "Failure", description: "Try again", item_index: 2, html:)
    }.to raise_error(DiscourseWorkflows::NodeError) { |error|
      expect(error.message).to eq("Failure [item 2]: Try again")
      expect(error.summary).to eq("Failure: Try again")
      expect(error.html).to eq(
        "<strong>Failure</strong><br><em>Try</em> <code>again</code>" \
          '<a href="/admin" title="Settings">Settings</a>' \
          '<a href="https://example.com">Help</a><a href="http://example.com">Docs</a>' \
          "<a>Unsafe</a><a>Data</a>",
      )
    }
  end

  it "keeps ordinary error markup as plain text" do
    body = '<img src="x" onerror="alert(1)">'

    expect {
      handler.send(:raise_node_error!, "HTTP request failed", description: body)
    }.to raise_error(DiscourseWorkflows::NodeError) { |error|
      expect(error.message).to eq("HTTP request failed: #{body}")
      expect(error.html).to be_nil
    }
  end

  it "falls back to plain text when sanitization removes all HTML content" do
    expect {
      handler.send(:raise_node_error!, "Failure", html: '<img src="x" onerror="alert(1)">')
    }.to raise_error(DiscourseWorkflows::NodeError) { |error|
      expect(error.message).to eq("Failure")
      expect(error.html).to be_nil
    }
  end
end
