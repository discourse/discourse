# frozen_string_literal: true

RSpec.describe CustomEmoji::ImportRow do
  describe "#stage" do
    subject(:staged_row) { row.stage(upload:, existing_emoji:) }

    fab!(:upload)

    let(:row) { described_class.new(index: 0, name: "party", group: "fun", filename: "party.png") }

    context "when no emoji exists with that name" do
      let(:existing_emoji) { nil }

      it "categorizes the row as new and records the incoming upload" do
        expect(staged_row.category).to eq(described_class::CATEGORY_NEW)
        expect(staged_row.upload_id).to eq(upload.id)
        expect(staged_row.incoming_url).to eq(upload.url)
      end
    end

    context "when an emoji exists with the same image and group" do
      fab!(:existing_emoji) { Fabricate(:custom_emoji, name: "party", group: "fun") }

      let(:upload) { existing_emoji.upload }

      it "categorizes the row as identical" do
        expect(staged_row.category).to eq(described_class::CATEGORY_IDENTICAL)
      end
    end

    context "when an emoji exists with the same image but another group" do
      fab!(:existing_emoji) { Fabricate(:custom_emoji, name: "party", group: "old") }

      let(:upload) { existing_emoji.upload }

      it "categorizes the row as a group conflict and records the existing state" do
        expect(staged_row.category).to eq(described_class::CATEGORY_CONFLICT_GROUP)
        expect(staged_row.existing_group).to eq("old")
        expect(staged_row.existing_url).to eq(existing_emoji.upload.url)
      end
    end

    context "when an emoji exists with another image but the same group" do
      fab!(:existing_emoji) { Fabricate(:custom_emoji, name: "party", group: "fun") }

      it "categorizes the row as an image conflict" do
        expect(staged_row.category).to eq(described_class::CATEGORY_CONFLICT_IMAGE)
      end
    end

    context "when an emoji exists with another image and another group" do
      fab!(:existing_emoji) { Fabricate(:custom_emoji, name: "party", group: "old") }

      it "categorizes the row as a conflict on both" do
        expect(staged_row.category).to eq(described_class::CATEGORY_CONFLICT_BOTH)
      end
    end
  end

  describe "#mark_invalid" do
    it "accumulates errors and categorizes the row as invalid" do
      row = described_class.new(index: 0, name: "party", group: nil, filename: "party.png")

      row.mark_invalid("first error", "second error")

      expect(row).to be_invalid
      expect(row.errors).to eq(["first error", "second error"])
    end
  end

  describe ".from_h" do
    it "round-trips a staged row through its hash representation" do
      row =
        described_class.new(
          index: 3,
          name: "party",
          group: "fun",
          filename: "party.png",
          category: described_class::CATEGORY_CONFLICT_GROUP,
          incoming_url: "/incoming.png",
          existing_url: "/existing.png",
          existing_group: "old",
          upload_id: 42,
        )

      expect(described_class.from_h(row.to_h.as_json).to_h).to eq(row.to_h)
    end
  end
end
