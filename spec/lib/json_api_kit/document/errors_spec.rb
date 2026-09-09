# frozen_string_literal: true

RSpec.describe JsonApiKit::Document::Errors do
  subject(:document) { described_class.new(not_found, bad_request) }

  let(:not_found) { JsonApiKit::NotFound.new }
  let(:bad_request) { JsonApiKit::BadRequest.new("Page size must be an integer.") }

  describe "#status" do
    it "returns the status of the first error" do
      expect(document.status).to eq("404")
    end
  end

  describe "#to_h" do
    it "renders every error in order" do
      expect(document.to_h[:errors].map { it[:title] }).to eq(["No such record", "Bad request"])
    end
  end
end
