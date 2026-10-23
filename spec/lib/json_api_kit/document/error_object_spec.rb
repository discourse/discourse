# frozen_string_literal: true

RSpec.describe JsonApiKit::Document::ErrorObject do
  subject(:error_object) { described_class.new(error) }

  let(:error_class) do
    Class.new(JsonApiKit::BadRequest) do
      def title = "Page size is too large"

      def source = { parameter: "page[size]" }

      def type = "https://example.com/errors/max-size"

      def meta = { page: { maxSize: 50 } }
    end
  end
  let(:error) { error_class.new("Page size 100 exceeds the maximum of 50.") }

  describe "#to_h" do
    it "renders every member of the error" do
      expect(error_object.to_h).to eq(
        status: "400",
        title: "Page size is too large",
        detail: "Page size 100 exceeds the maximum of 50.",
        source: {
          parameter: "page[size]",
        },
        links: {
          type: "https://example.com/errors/max-size",
        },
        meta: {
          page: {
            maxSize: 50,
          },
        },
      )
    end

    context "when the error holds no source, type or meta" do
      let(:error) { JsonApiKit::NotFound.new }

      it "drops every empty member" do
        expect(error_object.to_h).to eq(
          status: "404",
          title: "No such record",
          detail: "No record has this ID.",
        )
      end
    end
  end
end
