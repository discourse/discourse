# frozen_string_literal: true

RSpec.describe JsonApiKit::Name::ResourceScope do
  [
    JsonApiKit::Name::Field,
    JsonApiKit::Name::Sort,
    JsonApiKit::Name::Filter,
    JsonApiKit::Name::Anchor,
    JsonApiKit::Name::Relationship,
  ].each do |kind|
    describe kind do
      let(:name) { kind.new(value: "posted_at", type: "discussion_threads") }

      describe "#convert" do
        subject(:conversion) { name.convert(&:upcase) }

        it "converts the value and its owning type" do
          expect(conversion).to eq(kind.new(value: "POSTED_AT", type: "DISCUSSION_THREADS"))
        end
      end

      describe "#convert_type" do
        subject(:conversion) { name.convert_type(&:upcase) }

        it "converts only the owning type" do
          expect(conversion).to eq(name.with(type: "DISCUSSION_THREADS"))
        end
      end
    end
  end
end
