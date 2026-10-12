# frozen_string_literal: true

RSpec.describe JsonApiKit::VersionChange do
  subject(:version_change) { change_class.new("2026-09-10_remove_filters.rb") }

  let(:change_class) do
    Class.new(described_class) do
      version "2026-09-10"
      description "Topics remove their closed filter."
      resource(:topics) { removed_filter :closed }
    end
  end

  describe "#verify!" do
    subject(:verify) { version_change.verify! }

    before { freeze_time(Date.new(2026, 9, 18)) }

    it "accepts a removed filter" do
      expect { verify }.not_to raise_error
    end

    context "when the same filter is removed twice" do
      before { change_class.resource(:topics) { removed_filter :closed } }

      it "reports the conflicting name and source" do
        expect { verify }.to raise_error(
          ArgumentError,
          "2026-09-10_remove_filters.rb changes closed twice.",
        )
      end
    end

    context "when the same filter is both renamed and removed" do
      before { change_class.resource(:topics) { renamed_filter from: :closed, to: :archived } }

      it "rejects the conflicting declarations" do
        expect { verify }.to raise_error(ArgumentError, /changes closed twice/)
      end
    end

    context "when two resources remove the same filter name" do
      before { change_class.resource(:other_topics) { removed_filter :closed } }

      it "accepts the independent declarations" do
        expect { verify }.not_to raise_error
      end
    end
  end

  describe "#each_removed_filter" do
    subject(:filters) { version_change.enum_for(:each_removed_filter, type).to_a }

    let(:type) { "topics" }

    it "yields the retained declaration" do
      expect(filters).to contain_exactly(change_class.removed_filters.sole)
    end

    context "when the resource has no removed filters" do
      let(:type) { "users" }

      it "yields no filters" do
        expect(filters).to be_empty
      end
    end
  end
end
