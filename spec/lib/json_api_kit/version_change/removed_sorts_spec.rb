# frozen_string_literal: true

RSpec.describe JsonApiKit::VersionChange do
  subject(:version_change) { change_class.new("2026-09-10_remove_sorts.rb") }

  let(:change_class) do
    Class.new(described_class) do
      version "2026-09-10"
      description "Topics remove their created_at sort."
      resource(:topics) { removed_sort :created_at }
    end
  end

  describe "#verify!" do
    subject(:verify) { version_change.verify! }

    before { freeze_time(Date.new(2026, 9, 18)) }

    it "accepts a removed sort" do
      expect { verify }.not_to raise_error
    end

    context "when the same sort is removed twice" do
      before { change_class.resource(:topics) { removed_sort :created_at } }

      it "reports the conflicting name and source" do
        expect { verify }.to raise_error(
          ArgumentError,
          "2026-09-10_remove_sorts.rb changes created_at twice.",
        )
      end
    end

    context "when the same sort is both renamed and removed" do
      before { change_class.resource(:topics) { renamed_sort from: :created_at, to: :title } }

      it "rejects the conflicting declarations" do
        expect { verify }.to raise_error(ArgumentError, /changes created_at twice/)
      end
    end

    context "when an attribute rename also renames the removed sort" do
      before do
        change_class.resource(:topics) { renamed_attribute from: :created_at, to: :posted_at }
      end

      it "rejects the conflicting declarations" do
        expect { verify }.to raise_error(ArgumentError, /changes created_at twice/)
      end
    end

    context "when two resources remove the same sort name" do
      before { change_class.resource(:other_topics) { removed_sort :created_at } }

      it "accepts the independent declarations" do
        expect { verify }.not_to raise_error
      end
    end
  end

  describe "#each_removed_sort" do
    subject(:sorts) { version_change.enum_for(:each_removed_sort, type).to_a }

    let(:type) { "topics" }

    it "yields the retained declaration" do
      expect(sorts).to contain_exactly(change_class.removed_sorts.sole)
    end

    context "when the resource has no removed sorts" do
      let(:type) { "users" }

      it "yields no sorts" do
        expect(sorts).to be_empty
      end
    end
  end
end
