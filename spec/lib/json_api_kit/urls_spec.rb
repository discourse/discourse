# frozen_string_literal: true

RSpec.describe JsonApiKit::Urls do
  subject(:urls) { described_class.new(base:, current:, parameters:) }

  let(:base) { "https://example.com/api" }
  let(:current) { "https://example.com/api/topics" }
  let(:parameters) { { "page" => { "size" => "2" }, "sort" => "created_at" } }

  describe "#current" do
    it "returns the URL a caller read with the parameters they sent" do
      expect(urls.current.to_s).to eq(
        "https://example.com/api/topics?page%5Bsize%5D=2&sort=created_at",
      )
    end
  end

  describe "#for" do
    subject(:address) { urls.for(record).to_s }

    let(:record) { instance_double(JsonApiKit::Record, namespace: nil, type: "topics", id: "5") }

    it { is_expected.to eq("https://example.com/api/topics/5") }
  end
end
