# frozen_string_literal: true

RSpec.shared_examples "invalid limit params" do |endpoint, max_limit, extra_params|
  let(:params) { extra_params&.dig(:params) || {} }

  it "returns 400 response code when limit params is negative" do
    get endpoint, params: { limit: -1 }.merge(params)

    expect(response.status).to eq(400)
  end

  it "returns 400 response code when limit params is suspicious" do
    get endpoint, params: { limit: "1; DROP TABLE users" }.merge(params)

    expect(response.status).to eq(400)
  end

  it "returns 400 response code when limit params exceeds the max limit" do
    get endpoint, params: { limit: max_limit + 1 }.merge(params)

    expect(response.status).to eq(400)
  end
end
