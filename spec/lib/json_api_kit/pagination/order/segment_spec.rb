# frozen_string_literal: true

RSpec.describe JsonApiKit::Pagination::Order::Segment do
  subject(:segment) { described_class.new(id: 1, keyset:, condition:) }

  fab!(:pinned_topic) { Fabricate(:topic, pinned_at: Time.utc(2026, 8, 1)) }
  fab!(:unpinned_topic, :topic)
  fab!(:other_unpinned, :topic)

  let(:model) { Topic }
  let(:keyset) do
    JsonApiKit::Pagination::Keyset.new([JsonApiKit::Pagination::Keyset::Key.new(:id, model:)])
  end
  let(:condition) { ->(scope) { scope.where(pinned_at: nil) } }
  let(:scope) { Topic.where(id: [pinned_topic.id, unpinned_topic.id, other_unpinned.id]) }

  it { is_expected.to delegate_method(:columns).to(:keyset) }
  it { is_expected.to delegate_method(:compatible_with?).to(:keyset) }

  describe ".split" do
    subject(:segments) { described_class.split(keyset) }

    let(:key) { JsonApiKit::Pagination::Keyset::Key }
    let(:keys) { [key.new(:created_at, model:, direction: :desc), key.new(:id, model:)] }
    let(:keyset) { JsonApiKit::Pagination::Keyset.new(keys) }
    let(:unpinned_ids) { [unpinned_topic.id, other_unpinned.id] }

    context "when the leading key cannot be null" do
      it "returns one segment" do
        expect(segments.size).to eq(1)
      end

      it "gives that segment every row of the listing" do
        expect(segments.first.scope(scope)).to be(scope)
      end
    end

    context "when the leading key can be null" do
      let(:keys) do
        [key.new(:pinned_at, model:, direction: :desc, nulls: :last), key.new(:id, model:)]
      end

      it "returns two segments" do
        expect(segments.map(&:id)).to eq([0, 1])
      end

      it "gives the first segment the rows that hold a value" do
        expect(segments.first.scope(scope).map(&:id)).to contain_exactly(pinned_topic.id)
      end

      it "gives the second segment the rows that hold none" do
        expect(segments.last.scope(scope).map(&:id)).to match_array(unpinned_ids)
      end

      it "orders the first segment by that key then by id" do
        expect(segments.first.keyset.keys.map(&:name)).to eq(%i[pinned_at id])
      end

      it "drops that key from the second segment" do
        expect(segments.last.keyset.keys.map(&:name)).to eq([:id])
      end

      it "orders the first segment with no nulls placement" do
        expect(segments.first.keyset.order.join(" ")).not_to include("NULLS")
      end
    end

    context "when the leading key sorts its nulls first" do
      let(:keys) { [key.new(:pinned_at, model:, nulls: :first), key.new(:id, model:)] }

      it "puts the segment that holds the null rows first" do
        expect(segments.first.scope(scope).map(&:id)).to match_array(unpinned_ids)
      end
    end

    context "when no key follows a nullable key" do
      let(:keys) { [key.new(:pinned_at, model:, nulls: :last)] }

      it "refuses to split the keyset" do
        expect { segments }.to raise_error(ArgumentError)
      end
    end

    context "when a nullable key does not lead" do
      let(:keys) { [key.new(:created_at, model:), key.new(:pinned_at, model:, nulls: :last)] }

      it "returns one segment" do
        expect(segments.size).to eq(1)
      end
    end

    context "when two nullable keys lead" do
      let(:keys) do
        [
          key.new(:pinned_at, model:, nulls: :last),
          key.new(:bumped_at, model:, nulls: :last),
          key.new(:id, model:),
        ]
      end

      it "returns three segments" do
        expect(segments.size).to eq(3)
      end

      it "drops one more key from each segment" do
        expect(segments.map { it.keyset.keys.map(&:name) }).to eq(
          [%i[pinned_at bumped_at id], %i[bumped_at id], %i[id]],
        )
      end
    end
  end

  describe "#scope" do
    subject(:segment_ids) { segment.scope(scope) }

    it "returns only the rows the segment holds" do
      expect(segment_ids.map(&:id)).to contain_exactly(unpinned_topic.id, other_unpinned.id)
    end

    context "when the segment holds every row of the listing" do
      let(:condition) { described_class::NO_CONDITION }

      it "returns the same scope" do
        expect(segment_ids).to be(scope)
      end
    end
  end

  describe "#narrowed_by" do
    subject(:segment_ids) { segment.narrowed_by(other).scope(scope).map(&:id) }

    let(:other) { ->(scope) { scope.where(id: [pinned_topic.id, unpinned_topic.id]) } }

    it "returns the rows that both conditions keep" do
      expect(segment_ids).to contain_exactly(unpinned_topic.id)
    end

    context "when the other condition keeps rows the segment does not hold" do
      let(:other) { ->(scope) { scope.where(id: pinned_topic.id) } }

      it "returns no row" do
        expect(segment_ids).to be_empty
      end
    end
  end

  describe "#position_of" do
    subject(:position) { segment.position_of(record) }

    let(:record) { unpinned_topic }

    it "places the row in this segment" do
      expect(position.segment).to eq(segment)
    end

    it "carries the values this segment compares" do
      expect(position.values).to eq(keyset.values_for(record))
    end

    context "when the segment compares a timestamp" do
      let(:keyset) do
        JsonApiKit::Pagination::Keyset.new(
          [JsonApiKit::Pagination::Keyset::Key.new(:created_at, model:)],
        )
      end
      let(:record) { Topic.new(created_at: Time.utc(2026, 8, 3, 12, 0, 0, 123_456)) }
      let(:cursor) { position.to_cursor }

      it "writes a cursor that reads back the same values" do
        expect(JsonApiKit::Pagination::Cursor.parse(cursor.to_s)).to eq(cursor)
      end
    end
  end

  describe "#led_by?" do
    it { is_expected.to be_led_by(:id) }

    it { is_expected.not_to be_led_by(:created_at) }
  end

  describe "#reverse" do
    subject(:reversed_segment) { segment.reverse }

    it "keeps its id" do
      expect(reversed_segment.id).to eq(1)
    end

    it "keeps the rows it holds" do
      expect(reversed_segment.scope(scope).map(&:id)).to contain_exactly(
        unpinned_topic.id,
        other_unpinned.id,
      )
    end

    it "reads its keyset the other way" do
      expect(reversed_segment.keyset.keys.map { it.direction.to_sym }).to eq([:desc])
    end
  end
end
