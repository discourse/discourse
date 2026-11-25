# frozen_string_literal: true

require_relative "support"

# rubocop:disable Discourse/NoIterationOverRSpecDefinitions

describe DiscourseMcp::Server, "#call" do
  include_context "with unit four MCP writes"

  %i[forum pm].each do |kind|
    it "[cr-u4] refuses a labelled invalid UTF-8 decoded host under #{kind} with the normal reference refusal" do
      href = "https://visitor@%FF.example/page"
      raw = "Read [garden notes](#{href}) for seasonal observations."
      args = topic_arguments(raw:)
      isolated do
        data = expect_success(rpc("discourse_create_topic", args))
        written = Post.find(data.fetch("id"))
        expect(written.raw).to eq(raw)
        anchor = Nokogiri::HTML5.fragment(written.cooked).at_css("a")
        expect(anchor["href"]).to eq(href)
      end

      activate!(kind)
      expected = reference_error
      before_state = content_state
      response = rpc("discourse_create_topic", args)
      aggregate_failures do
        expect(response).to eq(expected),
        "INVALID UTF-8 HOST: expected the normal reference refusal, not an internal error"
        expect(content_state).to eq(before_state)
      end
    end
  end
end

# rubocop:enable Discourse/NoIterationOverRSpecDefinitions
