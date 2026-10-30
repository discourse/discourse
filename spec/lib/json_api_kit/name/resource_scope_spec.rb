# frozen_string_literal: true

RSpec.describe JsonApiKit::Name::ResourceScope do
  shared_examples "converting resource scope identifiers" do |kind|
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

  it_behaves_like "converting resource scope identifiers", JsonApiKit::Name::Field
  it_behaves_like "converting resource scope identifiers", JsonApiKit::Name::Sort
  it_behaves_like "converting resource scope identifiers", JsonApiKit::Name::Filter
  it_behaves_like "converting resource scope identifiers", JsonApiKit::Name::Anchor
  it_behaves_like "converting resource scope identifiers", JsonApiKit::Name::Relationship
end
