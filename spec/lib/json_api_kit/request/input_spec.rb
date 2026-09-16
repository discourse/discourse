# frozen_string_literal: true

RSpec.describe JsonApiKit::Request::Input do
  let(:resource) do
    Class.new(JsonApiKit::Resource) do
      model Topic
      type :topics
      sort :title
      default_sort title: :asc
    end
  end
  let(:default_sorts) { JsonApiKit::Edition.current.default_sorts }

  describe ".with_defaults" do
    subject(:parameters) { described_class.with_defaults(input, resource:, default_sorts:) }

    let(:input) { { page: { size: 1 } } }

    it "adds the default to the request parameters" do
      expect(parameters).to eq("page" => { size: 1 }, "sort" => { "title" => :asc })
    end

    it "preserves the original parameters" do
      parameters
      expect(input).to eq(page: { size: 1 })
    end

    context "when the request already has an ordering" do
      let(:input) { { "sort" => { "title" => :desc } } }

      it "preserves the explicit ordering" do
        expect(parameters).to eq(input)
      end
    end

    context "when the request has an empty ordering" do
      let(:input) { { "sort" => {} } }

      it "preserves the resolved empty ordering" do
        expect(parameters).to eq(input)
      end
    end

    context "when the request has an invalid ordering" do
      let(:input) { { "sort" => false } }

      it "preserves the value for validation" do
        expect(parameters).to eq(input)
      end
    end
  end
end
