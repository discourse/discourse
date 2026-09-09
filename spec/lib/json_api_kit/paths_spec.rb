# frozen_string_literal: true

RSpec.describe JsonApiKit::Paths do
  subject(:paths) { described_class.new(%w[user groups user.groups]) }

  describe "#relationship_names" do
    subject(:relationship_names) { paths.relationship_names }

    it "returns the relationships to read here" do
      expect(relationship_names).to eq(%w[user groups])
    end

    it "returns each relationship one time" do
      expect(relationship_names.count("user")).to eq(1)
    end

    context "when a client asks for nothing" do
      subject(:paths) { described_class.new(nil) }

      it "returns no relationship" do
        expect(relationship_names).to be_empty
      end
    end
  end

  describe "#next_for" do
    subject(:next_paths) { paths.next_for("user") }

    it "returns what the resource on the other side reads" do
      expect(next_paths.relationship_names).to eq(%w[groups])
    end

    context "when every path through that relationship ends there" do
      subject(:next_paths) { paths.next_for("groups") }

      it "returns nothing to read" do
        expect(next_paths).to be_empty
      end
    end

    context "when no path goes through that relationship" do
      subject(:next_paths) { paths.next_for("category") }

      it "returns nothing to read" do
        expect(next_paths).to be_empty
      end
    end

    context "when one reading gives its paths to the next" do
      subject(:paths) { described_class.new(described_class.new(%w[user.groups.members])) }

      it "reads them the same way" do
        expect(paths.next_for("user").relationship_names).to eq(%w[groups])
      end

      it "keeps each path whole" do
        expect(paths.next_for("user").map(&:to_s)).to eq(%w[user.groups.members])
      end
    end
  end

  describe "#+" do
    subject(:both_paths) { paths + described_class.new(%w[category]) }

    it "holds the paths of both" do
      expect(both_paths.map(&:to_s)).to eq(%w[user groups user.groups category])
    end
  end
end
