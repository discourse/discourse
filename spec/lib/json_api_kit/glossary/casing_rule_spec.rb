# frozen_string_literal: true

RSpec.describe JsonApiKit::Glossary::CasingRule do
  subject(:rule) { described_class }

  describe "#declared_name" do
    it "returns the name in snake case" do
      expect(rule.declared_name("createdAt")).to eq("created_at")
    end

    context "when the value is a list of names" do
      it "returns every name in snake case" do
        expect(rule.declared_name("-createdAt,title")).to eq("-created_at,title")
      end
    end

    context "when the value is a path" do
      it "returns every segment" do
        expect(rule.declared_name("solvedStatus.answeredAt")).to eq("solved_status.answered_at")
      end
    end

    context "when the name has a hyphen" do
      it "keeps the hyphen" do
        expect(rule.declared_name("solved-statuses")).to eq("solved-statuses")
      end
    end

    context "when the name starts with a capital" do
      it do
        expect { rule.declared_name("CreatedAt") }.to raise_error(described_class::NotAMemberName)
      end
    end

    context "when the name ends with capitals" do
      it do
        expect { rule.declared_name("createdAT") }.to raise_error(described_class::NotAMemberName)
      end
    end

    context "when the name has an underscore" do
      it do
        expect { rule.declared_name("created_at") }.to raise_error(described_class::NotAMemberName)
      end

      it "suggests the name to use instead" do
        expect { rule.declared_name("created_at") }.to raise_error(
          /Use createdAt, not created_at\./,
        )
      end
    end
  end

  describe "#member_name" do
    it "returns the name in camel case" do
      expect(rule.member_name("created_at")).to eq("createdAt")
    end

    context "when the name is a path" do
      it "returns every segment" do
        expect(rule.member_name("last_poster.last_seen_at")).to eq("lastPoster.lastSeenAt")
      end
    end

    context "when the name has a hyphen" do
      it "keeps the hyphen" do
        expect(rule.member_name("solved-statuses")).to eq("solved-statuses")
      end
    end
  end
end
