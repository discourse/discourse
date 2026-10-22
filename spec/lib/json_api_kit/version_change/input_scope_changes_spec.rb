# frozen_string_literal: true

RSpec.describe JsonApiKit::VersionChange do
  subject(:version_change) { change_class.new("2026-09-10_change_input_scope.rb") }

  let(:change_class) do
    Class.new(described_class) do
      version "2026-09-10"
      description "Workable topics change how they narrow."
      resource(:topics) do
        collection(:workable) { changed_input_scope { |topics, _guardian| topics.none } }
      end
    end
  end

  describe "#verify!" do
    subject(:verify) { version_change.verify! }

    before { freeze_time(Date.new(2026, 9, 18)) }

    it "accepts a changed input scope" do
      expect { verify }.not_to raise_error
    end

    context "when the same listing changes its input scope twice" do
      before do
        change_class.resource(:topics) do
          collection(:workable) { changed_input_scope { |topics, _guardian| topics } }
        end
      end

      it "reports the conflict and the source" do
        expect { verify }.to raise_error(
          ArgumentError,
          "2026-09-10_change_input_scope.rb changes the input scope of topics workable twice.",
        )
      end
    end

    context "when the resource and its collection each change their input scope" do
      before do
        change_class.resource(:topics) { changed_input_scope { |topics, _guardian| topics } }
      end

      it "accepts the independent declarations" do
        expect { verify }.not_to raise_error
      end
    end
  end

  describe "#each_input_scope_change" do
    subject(:changes) do
      version_change.enum_for(:each_input_scope_change, "topics", collection).to_a
    end

    let(:collection) { "workable" }

    it "yields the collection's change" do
      expect(changes.map(&:collection)).to eq(["workable"])
    end

    context "when the resource itself is asked" do
      let(:collection) { nil }

      it "yields no change" do
        expect(changes).to be_empty
      end
    end
  end
end
