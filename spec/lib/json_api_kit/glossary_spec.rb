# frozen_string_literal: true

module JsonApiKitSpec
  MarkingRule =
    Struct.new(:mark) do
      def declared_name(name) = "#{name}<#{mark}"

      def member_name(name) = "#{name}>#{mark}"
    end
end

RSpec.describe JsonApiKit::Glossary do
  subject(:glossary) { described_class.new([JsonApiKit::Glossary::CasingRule]) }

  describe ".kit" do
    subject(:kit) { described_class.kit }

    before { allow(described_class).to receive(:new).and_call_original }

    it "builds a glossary with the wire format rules" do
      kit
      expect(described_class).to have_received(:new).with([JsonApiKit::Glossary::CasingRule])
    end
  end

  describe ".resource" do
    subject(:resource) { described_class.resource }

    before { allow(described_class).to receive(:new).and_call_original }

    it "builds a glossary with the rules for a resource" do
      resource
      expect(described_class).to have_received(:new).with([JsonApiKit::Glossary::CasingRule])
    end
  end

  describe "#declared_name" do
    it "returns the declared name" do
      expect(glossary.declared_name("createdAt")).to eq("created_at")
    end

    context "with several rules" do
      subject(:glossary) { described_class.new([mark_a, mark_b]) }

      let(:mark_a) { JsonApiKitSpec::MarkingRule.new("a") }
      let(:mark_b) { JsonApiKitSpec::MarkingRule.new("b") }

      it "applies them in order" do
        expect(glossary.declared_name("x")).to eq("x<a<b")
      end
    end
  end

  describe "#member_name" do
    it "returns the member name" do
      expect(glossary.member_name("created_at")).to eq("createdAt")
    end

    context "with several rules" do
      subject(:glossary) { described_class.new([mark_a, mark_b]) }

      let(:mark_a) { JsonApiKitSpec::MarkingRule.new("a") }
      let(:mark_b) { JsonApiKitSpec::MarkingRule.new("b") }

      it "applies them in reverse order" do
        expect(glossary.member_name("x")).to eq("x>b>a")
      end
    end
  end
end
