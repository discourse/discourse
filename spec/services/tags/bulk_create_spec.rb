# frozen_string_literal: true

RSpec.describe(Tags::BulkCreate) do
  describe described_class::Contract, type: :model do
    it "rejects nil tag_names" do
      contract = described_class.new(tag_names: nil)
      expect(contract.valid?).to be false
      expect(contract.errors[:tag_names]).to be_present
    end

    it "rejects non-array tag_names" do
      contract = described_class.new(tag_names: "not an array")
      expect(contract.valid?).to be false
      expect(contract.errors[:tag_names]).to be_present
    end

    it "validates tag_names limit" do
      contract = described_class.new(tag_names: (1..101).map { |i| "tag#{i}" })
      expect(contract.valid?).to be false
      expect(contract.errors[:tag_names]).to be_present
      expect(contract.errors[:tag_names].first).to include("Too many tags")
    end
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:current_user, :admin)

    let(:params) { { tag_names: } }
    let(:dependencies) { { guardian: current_user.guardian } }
    let(:tag_names) { %w[tag1 tag2 tag3] }

    context "when user is not allowed to perform the action" do
      fab!(:current_user, :user)

      it { is_expected.to fail_a_policy(:can_admin_tags) }
    end

    context "when contract is invalid" do
      let(:tag_names) { nil }

      it { is_expected.to fail_a_contract }
    end

    context "when tag_names is not an array" do
      let(:tag_names) { "not an array" }

      it { is_expected.to fail_a_contract }
    end

    context "when tag_names exceeds limit" do
      let(:tag_names) { (1..101).map { |i| "tag#{i}" } }

      it { is_expected.to fail_a_contract }
    end

    context "when everything's ok" do
      it { is_expected.to run_successfully }

      it "creates the tags" do
        expect { result }.to change { Tag.count }.by(3)
        expect(Tag.where(name: tag_names).count).to eq(3)
      end

      it "returns the created tags" do
        expect(result.results[:created]).to contain_exactly("tag1", "tag2", "tag3")
        expect(result.results[:existing]).to be_empty
        expect(result.results[:failed]).to be_empty
      end
    end

    context "when some tags already exist" do
      fab!(:existing_tag) { Fabricate(:tag, name: "existing-tag") }

      let(:tag_names) { %w[existing-tag new-tag] }

      it { is_expected.to run_successfully }

      it "creates only new tags" do
        expect { result }.to change { Tag.count }.by(1)
      end

      it "reports existing tags separately" do
        expect(result.results[:created]).to contain_exactly("new-tag")
        expect(result.results[:existing]).to contain_exactly("existing-tag")
        expect(result.results[:failed]).to be_empty
      end
    end

    context "when tags need cleaning" do
      let(:tag_names) { ["Tag With Spaces", "UPPERCASE"] }

      it { is_expected.to run_successfully }

      it "cleans tag names" do
        result
        expect(Tag.where(name: %w[tag-with-spaces uppercase]).count).to eq(2)
      end

      it "returns cleaned names" do
        expect(result.results[:created]).to contain_exactly("tag-with-spaces", "uppercase")
      end
    end

    context "when force_lowercase_tags is disabled" do
      let(:tag_names) { ["CamelCase", "UPPERCASE", "Tag With Spaces"] }

      before { SiteSetting.force_lowercase_tags = false }

      it { is_expected.to run_successfully }

      it "preserves case in tag names" do
        result
        expect(Tag.where(name: %w[CamelCase UPPERCASE Tag-With-Spaces]).count).to eq(3)
      end

      it "returns preserved-case names" do
        expect(result.results[:created]).to contain_exactly(
          "CamelCase",
          "UPPERCASE",
          "Tag-With-Spaces",
        )
        expect(result.results[:failed]).to be_empty
      end
    end

    context "when tag names are numbers" do
      let(:tag_names) { [123, 456, 789] }

      it { is_expected.to run_successfully }

      it "converts numbers to strings and creates tags" do
        expect { result }.to change { Tag.count }.by(3)
        expect(Tag.where(name: %w[123 456 789]).count).to eq(3)
      end

      it "returns the created tags as strings" do
        expect(result.results[:created]).to contain_exactly("123", "456", "789")
      end
    end

    context "when tag names have leading zeros" do
      let(:tag_names) { %w[0000 0123 00test] }

      it { is_expected.to run_successfully }

      it "preserves leading zeros" do
        expect { result }.to change { Tag.count }.by(3)
        expect(Tag.where(name: %w[0000 0123 00test]).count).to eq(3)
      end

      it "returns tags with leading zeros preserved" do
        expect(result.results[:created]).to contain_exactly("0000", "0123", "00test")
      end
    end

    context "when some tags are invalid" do
      let(:tag_names) { ["", "valid-tag", "   ", "%^&ui^&*", "!!!test"] }

      it { is_expected.to run_successfully }

      it "creates only valid tags" do
        expect { result }.to change { Tag.count }.by(1)
      end

      it "reports failed tags" do
        expect(result.results[:created]).to contain_exactly("valid-tag")
        expect(result.results[:failed].keys).to contain_exactly("%^&ui^&*", "!!!test")
      end
    end

    context "when a tag is too long" do
      let(:long_tag) { "a" * (SiteSetting.max_tag_length + 1) }
      let(:tag_names) { [long_tag, "short-tag"] }

      it { is_expected.to run_successfully }

      it "creates only valid tags" do
        expect { result }.to change { Tag.count }.by(1)
      end

      it "reports the error" do
        expect(result.results[:created]).to contain_exactly("short-tag")
        expect(result.results[:failed][long_tag]).to be_present
        expect(result.results[:failed][long_tag]).to include("too long")
      end
    end

    context "when tag_names array is empty" do
      let(:tag_names) { [] }

      it { is_expected.to run_successfully }

      it "returns empty results" do
        expect(result.results[:created]).to be_empty
        expect(result.results[:existing]).to be_empty
        expect(result.results[:failed]).to be_empty
      end
    end

    context "when mixing valid, existing, and invalid tags" do
      fab!(:existing_tag) { Fabricate(:tag, name: "existing") }

      let(:tag_names) { ["new-tag", "existing", "", "invalid@@@", "another-new"] }

      it { is_expected.to run_successfully }

      it "processes all tags correctly" do
        expect { result }.to change { Tag.count }.by(2)
        expect(result.results[:created]).to contain_exactly("new-tag", "another-new")
        expect(result.results[:existing]).to contain_exactly("existing")
        expect(result.results[:failed].keys).to contain_exactly("invalid@@@")
      end
    end
  end
end
