# frozen_string_literal: true

RSpec.describe JsonApiKit::Request::Body do
  subject(:body) { described_class.parse(document.to_json, resource:) }

  let(:document) { { "data" => { "type" => "topics", "attributes" => { "title" => nil } } } }
  let(:resource) do
    Class
      .new(JsonApiKit::Resource) do
        model Topic
        type :topics
      end
      .new(guardian: Guardian.new)
  end

  describe "#to_h" do
    before { body.invalid? }

    it "preserves the supplied document" do
      expect(body.to_h).to eq(document)
    end
  end

  describe "#refusals" do
    subject(:refusals) { body.refusals }

    let(:document) { { "data" => { "type" => 123, "attributes" => [] } } }

    before { body.invalid? }

    it "reports each invalid member" do
      expect(refusals.map(&:source)).to contain_exactly(
        { pointer: "/data/type" },
        { pointer: "/data/attributes" },
      )
    end

    it "explains the invalid type" do
      expect(refusals.map(&:detail)).to include("type must be a string.")
    end
  end

  describe "#invalid?" do
    context "when the type is an empty array" do
      let(:document) { { "data" => { "type" => [] } } }

      it { is_expected.to be_invalid }
    end

    context "when the type is an array containing the expected type" do
      let(:document) { { "data" => { "type" => ["topics"] } } }

      it { is_expected.to be_invalid }
    end
  end
end
