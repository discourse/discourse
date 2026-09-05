# frozen_string_literal: true

RSpec.describe JsonApiKit::Glossary::CasingRule do
  let(:rule) { described_class }
  let(:name) { JsonApiKit::Name::Field.new(value:, type: "topics") }
  let(:value) { "createdAt" }

  describe "#declared_name" do
    subject(:declared_name) { rule.declared_name(name) }

    it "returns the name in snake case" do
      expect(declared_name).to eq(name.with(value: "created_at"))
    end

    context "when the value is a list of names" do
      let(:name) { JsonApiKit::Name::Member.new(value: "-createdAt,title") }

      it "returns every name in snake case" do
        expect(declared_name).to eq(name.with(value: "-created_at,title"))
      end
    end

    context "when the value is a path" do
      let(:name) { JsonApiKit::Name::Member.new(value: "solvedStatus.answeredAt") }

      it "returns every segment" do
        expect(declared_name).to eq(name.with(value: "solved_status.answered_at"))
      end
    end

    context "when the name has a hyphen" do
      let(:name) { JsonApiKit::Name::Member.new(value: "solved-statuses") }

      it "keeps the hyphen" do
        expect(declared_name).to eq(name)
      end
    end

    context "when the name starts with a capital" do
      let(:value) { "CreatedAt" }

      it { expect { declared_name }.to raise_error(JsonApiKit::Glossary::Correction) }
    end

    context "when the name ends with capitals" do
      let(:value) { "createdAT" }

      it { expect { declared_name }.to raise_error(JsonApiKit::Glossary::Correction) }
    end

    context "when the name has an underscore" do
      let(:value) { "created_at" }

      it { expect { declared_name }.to raise_error(JsonApiKit::Glossary::Correction) }

      it "raises a correction with the name in snake case" do
        expect { declared_name }.to raise_error(having_attributes(name:))
      end
    end
  end

  describe "#member_name" do
    subject(:member_name) { rule.member_name(name) }

    let(:value) { "created_at" }

    it "returns the name in camel case" do
      expect(member_name).to eq(name.with(value: "createdAt"))
    end

    context "when the name is a path" do
      let(:name) { JsonApiKit::Name::Member.new(value: "last_poster.last_seen_at") }

      it "returns every segment" do
        expect(member_name).to eq(name.with(value: "lastPoster.lastSeenAt"))
      end
    end

    context "when the name has a hyphen" do
      let(:name) { JsonApiKit::Name::Member.new(value: "solved-statuses") }

      it "keeps the hyphen" do
        expect(member_name).to eq(name)
      end
    end
  end
end
