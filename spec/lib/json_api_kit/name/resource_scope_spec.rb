# frozen_string_literal: true

RSpec.describe JsonApiKit::Name::ResourceScope do
  shared_examples "converting resource scope identifiers" do |identifier_class:|
    let(:name) { identifier_class.new(value: "posted_at", type: "discussion_threads") }

    describe "#convert" do
      subject(:conversion) { name.convert(&:upcase) }

      it "converts the value and its owning type" do
        expect(conversion).to eq(
          identifier_class.new(value: "POSTED_AT", type: "DISCUSSION_THREADS"),
        )
      end
    end

    describe "#convert_type" do
      subject(:conversion) { name.convert_type(&:upcase) }

      it "converts only the owning type" do
        expect(conversion).to eq(name.with(type: "DISCUSSION_THREADS"))
      end
    end
  end

  context "for field identifiers" do
    include_examples "converting resource scope identifiers",
                     identifier_class: JsonApiKit::Name::Field
  end

  context "for sort identifiers" do
    include_examples "converting resource scope identifiers",
                     identifier_class: JsonApiKit::Name::Sort
  end

  context "for filter identifiers" do
    include_examples "converting resource scope identifiers",
                     identifier_class: JsonApiKit::Name::Filter
  end

  context "for anchor identifiers" do
    include_examples "converting resource scope identifiers",
                     identifier_class: JsonApiKit::Name::Anchor
  end

  context "for relationship identifiers" do
    include_examples "converting resource scope identifiers",
                     identifier_class: JsonApiKit::Name::Relationship
  end
end
