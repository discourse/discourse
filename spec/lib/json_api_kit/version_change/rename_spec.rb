# frozen_string_literal: true

RSpec.describe JsonApiKit::VersionChange::Rename do
  subject(:rename) do
    described_class.new(kind: :field, type: "topics", from: "posted_at", to: "created_at")
  end

  let(:old_name) { JsonApiKit::Name::Field.new(value: "posted_at", type: "topics") }
  let(:new_name) { JsonApiKit::Name::Field.new(value: "created_at", type: "topics") }

  describe "#current" do
    it "returns the new name for the old one" do
      expect(rename.current(old_name)).to eq(new_name)
    end

    context "when the name is of another kind" do
      let(:old_name) { JsonApiKit::Name::Sort.new(value: "posted_at", type: "topics") }

      it "returns the name" do
        expect(rename.current(old_name)).to eq(old_name)
      end
    end

    context "when the name is of another type" do
      let(:old_name) { JsonApiKit::Name::Field.new(value: "posted_at", type: "users") }

      it "returns the name" do
        expect(rename.current(old_name)).to eq(old_name)
      end
    end
  end

  describe "#previous" do
    it "returns the old name for the new one" do
      expect(rename.previous(new_name)).to eq(old_name)
    end

    context "when the name is of another kind" do
      let(:new_name) { JsonApiKit::Name::Sort.new(value: "created_at", type: "topics") }

      it "returns the name" do
        expect(rename.previous(new_name)).to eq(new_name)
      end
    end

    context "when the name is of another type" do
      let(:new_name) { JsonApiKit::Name::Field.new(value: "created_at", type: "users") }

      it "returns the name" do
        expect(rename.previous(new_name)).to eq(new_name)
      end
    end
  end

  describe "#introduces?" do
    it { expect(rename).to be_introduces(new_name) }
    it { expect(rename).not_to be_introduces(old_name) }
  end
end
