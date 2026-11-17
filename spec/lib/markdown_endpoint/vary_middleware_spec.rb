# frozen_string_literal: true

require "rails_helper"

RSpec.describe MarkdownEndpoint::VaryMiddleware do
  it "preserves Vary tokens and handles Accept case-insensitively" do
    app = ->(_env) { [301, { "vArY" => "Origin, aCcEpT" }, []] }
    env = { MarkdownEndpoint::RequestConstraint::VARY_ACCEPT_ENV_KEY => true }

    _status, headers, _body = described_class.new(app).call(env)

    expect(headers).to eq("vArY" => "Origin, aCcEpT")

    app = ->(_env) { [404, { "Vary" => "Origin" }, []] }
    _status, headers, _body = described_class.new(app).call(env)

    expect(headers).to eq("Vary" => "Origin, Accept")
  end
end
