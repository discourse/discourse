# frozen_string_literal: true

RSpec.describe "filter parameter logging" do
  it "redacts traffic filters that can contain sensitive values" do
    filter = ActiveSupport::ParameterFilter.new(Rails.application.config.filter_parameters)

    expect(
      filter.filter(
        "top_url" => "/private?token=top-secret",
        "entry_url" => "/private-entry",
        "referrer" => "private.example",
        "ip" => "192.0.2.1",
        "country" => "US",
      ),
    ).to eq(
      "top_url" => "[FILTERED]",
      "entry_url" => "[FILTERED]",
      "referrer" => "[FILTERED]",
      "ip" => "[FILTERED]",
      "country" => "US",
    )
  end
end
