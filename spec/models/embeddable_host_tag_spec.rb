#frozen_string_literal: true

RSpec.describe EmbeddableHostTag, type: :model do
  describe "associations" do
    it "belongs to an embeddable_host" do
      expect(described_class.reflect_on_association(:embeddable_host).macro).to eq(:belongs_to)
    end

    it "belongs to a tag" do
      expect(described_class.reflect_on_association(:tag).macro).to eq(:belongs_to)
    end
  end

  describe "validations" do
    subject { Fabricate(:embeddable_host_tag) }

    it { is_expected.to validate_presence_of(:embeddable_host_id) }
    it { is_expected.to validate_presence_of(:tag_id) }
    it { is_expected.to validate_uniqueness_of(:embeddable_host_id).scoped_to(:tag_id) }
  end

  describe "functionality" do
    context "when creating valid associations" do
      let(:embeddable_host) { Fabricate(:embeddable_host) }
      let(:tag) { Fabricate(:tag) }

      it "successfully creates an embeddable_host_tag with valid inputs" do
        host_tag = EmbeddableHostTag.new(embeddable_host: embeddable_host, tag: tag)
        expect(host_tag.save).to be true
      end
    end

    context "when attempting to create duplicate associations" do
      let(:embeddable_host) { Fabricate(:embeddable_host) }
      let(:tag) { Fabricate(:tag) }

      before { EmbeddableHostTag.create!(embeddable_host: embeddable_host, tag: tag) }

      it "prevents duplicate embeddable_host_tag from being saved" do
        duplicate_host_tag = EmbeddableHostTag.new(embeddable_host: embeddable_host, tag: tag)
        expect(duplicate_host_tag.valid?).to be false
        expect(duplicate_host_tag.errors[:embeddable_host_id]).to include("has already been taken")
      end
    end

    context "with missing fields" do
      it "fails to save without an embeddable_host" do
        host_tag = EmbeddableHostTag.new(tag: Fabricate(:tag))
        expect(host_tag.valid?).to be false
      end

      it "fails to save without a tag" do
        host_tag = EmbeddableHostTag.new(embeddable_host: Fabricate(:embeddable_host))
        expect(host_tag.valid?).to be false
      end
    end
  end
end
