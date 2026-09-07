# frozen_string_literal: true

module JsonApiKitSpec
  MarkingRule =
    Struct.new(:mark) do
      def declared_name(name) = name.convert { "#{it}<#{mark}" }

      def member_name(name) = name.convert { "#{it}>#{mark}" }

      def declared_attributes(attributes) = attributes.transform_keys { declared_name(it) }

      def member_attributes(attributes) = attributes.transform_keys { member_name(it) }
    end

  class GlossaryChange < JsonApiKit::VersionChange
    version "2026-09-15"
    description "The `posted_at` attribute of the topics resource is renamed to `created_at`."

    resource :topics do
      renamed_attribute from: :posted_at, to: :created_at
    end
  end

  class GlossaryShapeChange < JsonApiKit::VersionChange
    version "2026-09-15"
    description "The `words` attribute of the topics resource becomes `title`, a string."

    resource :topics do
      renamed_attribute from: :words,
                        to: :title,
                        down: ->(title) { title.to_s.split(" ") },
                        up: ->(words) { words.to_a.join(" ") }
    end
  end

  class GlossaryReuseChange < JsonApiKit::VersionChange
    version "2026-10-01"
    description "The `label` attribute of the topics resource is renamed to `posted_at`."

    resource :topics do
      renamed_attribute from: :label, to: :posted_at
    end
  end
end

RSpec.describe JsonApiKit::Glossary do
  subject(:glossary) { described_class.new([described_class::CasingRule]) }

  let(:version) { JsonApiKit::Timeline::FIRST_RELEASE }
  let(:change) { JsonApiKitSpec::GlossaryChange.new(__FILE__) }
  let(:name) { JsonApiKit::Name::Field.new(value:, type: "topics") }
  let(:value) { "createdAt" }

  describe ".kit" do
    subject(:kit) { described_class.kit }

    before { allow(described_class).to receive(:new).and_call_original }

    it "builds a glossary with the wire format rules" do
      kit
      expect(described_class).to have_received(:new).with([described_class::CasingRule])
    end
  end

  describe ".resource" do
    subject(:resource) { described_class.resource(version) }

    before do
      allow(described_class).to receive(:new).and_call_original
      allow(described_class::VersionRule).to receive(:new).and_call_original
    end

    it "builds a glossary with the wire format rules and the version rule" do
      resource
      expect(described_class).to have_received(:new).with(
        [described_class::CasingRule, an_instance_of(described_class::VersionRule)],
      )
    end

    it "builds the version rule for the version" do
      resource
      expect(described_class::VersionRule).to have_received(:new).with(version)
    end
  end

  describe "#declared_attributes" do
    subject(:declared_attributes) { glossary.declared_attributes(attributes) }

    let(:attributes) { { name => "Anchors and pages" } }

    it "returns the attributes with their declared names" do
      expect(declared_attributes).to eq(name.with(value: "created_at") => "Anchors and pages")
    end

    context "when a name is not a member name" do
      let(:value) { "created_at" }

      it "raises with the member name to use" do
        expect { declared_attributes }.to raise_error(/Use createdAt, not created_at\./)
      end
    end

    context "with a version rule" do
      subject(:glossary) { described_class.resource(version) }

      let(:attributes) { { name => %w[Anchors and pages] } }
      let(:value) { "words" }

      before do
        allow(JsonApiKit::VersionChange).to receive(:after).with(version).and_return(
          [JsonApiKitSpec::GlossaryShapeChange.new(__FILE__)],
        )
      end

      it "returns the attributes with the current names and shapes" do
        expect(declared_attributes).to eq(name.with(value: "title") => "Anchors and pages")
      end

      context "when a name belongs to a later version" do
        let(:value) { "title" }

        it "raises with the name of this version" do
          expect { declared_attributes }.to raise_error(/Use words, not title\./)
        end
      end
    end

    context "with several rules" do
      subject(:glossary) { described_class.new([mark_a, mark_b]) }

      let(:mark_a) { JsonApiKitSpec::MarkingRule.new("a") }
      let(:mark_b) { JsonApiKitSpec::MarkingRule.new("b") }

      it "applies them in order" do
        expect(declared_attributes).to eq(name.with(value: "createdAt<a<b") => "Anchors and pages")
      end
    end
  end

  describe "#declared_name" do
    subject(:declared_name) { glossary.declared_name(name) }

    it "returns the declared name" do
      expect(declared_name).to eq(name.with(value: "created_at"))
    end

    context "when the name was converted before" do
      before do
        allow(described_class::CasingRule).to receive(:declared_name).and_call_original
        glossary.declared_name(name)
      end

      it "does not ask the rules again" do
        declared_name
        expect(described_class::CasingRule).to have_received(:declared_name).once
      end
    end

    context "when the name was refused before" do
      let(:value) { "created_at" }

      before do
        allow(described_class::CasingRule).to receive(:declared_name).and_call_original
        suppress(described_class::NotAMemberName) { glossary.declared_name(name) }
      end

      it "asks the rules again" do
        suppress(described_class::NotAMemberName) { declared_name }
        expect(described_class::CasingRule).to have_received(:declared_name).twice
      end
    end

    context "when the name is not a member name" do
      let(:value) { "created_at" }

      it "raises a refusal" do
        expect { declared_name }.to raise_error(described_class::NotAMemberName)
      end

      it "suggests the name to use instead" do
        expect { declared_name }.to raise_error(/Use createdAt, not created_at\./)
      end
    end

    context "with a version rule" do
      subject(:glossary) { described_class.resource(version) }

      let(:value) { "postedAt" }

      before do
        allow(JsonApiKit::VersionChange).to receive(:after).with(version).and_return([change])
      end

      it "returns the current name" do
        expect(declared_name).to eq(name.with(value: "created_at"))
      end

      context "when the name belongs to a later version" do
        let(:value) { "createdAt" }

        it "suggests the name of this version, on the wire" do
          expect { declared_name }.to raise_error(/Use postedAt, not createdAt\./)
        end
      end

      context "when the name is in snake case" do
        let(:value) { "created_at" }

        it "suggests the name of this version, on the wire" do
          expect { declared_name }.to raise_error(/Use postedAt, not created_at\./)
        end
      end

      context "when a later change reuses a spelling of this version" do
        let(:value) { "createdAt" }

        before do
          allow(JsonApiKit::VersionChange).to receive(:after).with(version).and_return(
            [change, JsonApiKitSpec::GlossaryReuseChange.new(__FILE__)],
          )
        end

        it "suggests the name of this version, on the wire" do
          expect { declared_name }.to raise_error(/Use postedAt, not createdAt\./)
        end
      end
    end

    context "with several rules" do
      subject(:glossary) { described_class.new([mark_a, mark_b]) }

      let(:mark_a) { JsonApiKitSpec::MarkingRule.new("a") }
      let(:mark_b) { JsonApiKitSpec::MarkingRule.new("b") }

      it "applies them in order" do
        expect(declared_name).to eq(name.with(value: "createdAt<a<b"))
      end
    end
  end

  describe "#member_attributes" do
    subject(:member_attributes) { glossary.member_attributes(name => "Anchors and pages") }

    let(:value) { "title" }

    it "returns the attributes with their member names" do
      expect(member_attributes).to eq(name => "Anchors and pages")
    end

    context "with a version rule" do
      subject(:glossary) { described_class.resource(version) }

      before do
        allow(JsonApiKit::VersionChange).to receive(:after).with(version).and_return(
          [JsonApiKitSpec::GlossaryShapeChange.new(__FILE__)],
        )
      end

      it "returns the attributes with the names and the values of this version, on the wire" do
        expect(member_attributes).to eq(name.with(value: "words") => %w[Anchors and pages])
      end
    end

    context "with several rules" do
      subject(:glossary) { described_class.new([mark_a, mark_b]) }

      let(:mark_a) { JsonApiKitSpec::MarkingRule.new("a") }
      let(:mark_b) { JsonApiKitSpec::MarkingRule.new("b") }

      it "applies them in reverse order" do
        expect(member_attributes).to eq(name.with(value: "title>b>a") => "Anchors and pages")
      end
    end
  end

  describe "#member_name" do
    subject(:member_name) { glossary.member_name(name) }

    let(:value) { "created_at" }

    it "returns the member name" do
      expect(member_name).to eq(name.with(value: "createdAt"))
    end

    context "when the name was converted before" do
      before do
        allow(described_class::CasingRule).to receive(:member_name).and_call_original
        glossary.member_name(name)
      end

      it "does not ask the rules again" do
        member_name
        expect(described_class::CasingRule).to have_received(:member_name).once
      end
    end

    context "with a version rule" do
      subject(:glossary) { described_class.resource(version) }

      before do
        allow(JsonApiKit::VersionChange).to receive(:after).with(version).and_return([change])
      end

      it "returns the name of this version, on the wire" do
        expect(member_name).to eq(name.with(value: "postedAt"))
      end
    end

    context "with several rules" do
      subject(:glossary) { described_class.new([mark_a, mark_b]) }

      let(:mark_a) { JsonApiKitSpec::MarkingRule.new("a") }
      let(:mark_b) { JsonApiKitSpec::MarkingRule.new("b") }

      it "applies them in reverse order" do
        expect(member_name).to eq(name.with(value: "created_at>b>a"))
      end
    end
  end
end
