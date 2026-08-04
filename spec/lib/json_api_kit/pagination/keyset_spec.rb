# frozen_string_literal: true

RSpec.describe JsonApiKit::Pagination::Keyset do
  subject(:keyset) { described_class.new(keys) }

  let(:keys) do
    [described_class::Key.new(:created_at, direction: :desc), described_class::Key.new(:id)]
  end

  describe ".new" do
    context "without a single key" do
      let(:keys) { [] }

      it "refuses to build an order out of nothing" do
        expect { keyset }.to raise_error(ArgumentError)
      end
    end
  end

  describe "#order" do
    subject(:order) { keyset.order }

    it "orders by every key, each its own way" do
      expect(order).to eq(created_at: :desc, id: :asc)
    end

    context "with a nullable key" do
      let(:keys) do
        [
          described_class::Key.new(:bumped_at, direction: :desc, nulls_last: true),
          described_class::Key.new(:id),
        ]
      end

      it "sorts on the key's null flag before the key itself" do
        expect(order.keys).to eq(%i[bumped_at_is_null bumped_at id])
      end

      it "sends the nulls last, whichever way the key itself sorts" do
        expect(order).to eq(bumped_at_is_null: :asc, bumped_at: :desc, id: :asc)
      end
    end

    context "with a key already in the order" do
      let(:keys) do
        [
          described_class::Key.new(:id, direction: :desc),
          described_class::Key.new(:created_at),
          described_class::Key.new(:id),
        ]
      end

      it "keeps the first place the key takes" do
        expect(order.keys).to eq(%i[id created_at])
      end

      it "keeps the direction it was first given" do
        expect(order[:id]).to eq(:desc)
      end
    end
  end

  describe "#joins" do
    subject(:joins) { keyset.joins }

    let(:keys) do
      [
        described_class::Key.new(:username, sql: "users.username", joins: [:user]),
        described_class::Key.new(:title, sql: "topics.title", joins: [:user]),
      ]
    end

    it "asks for each join once" do
      expect(joins).to contain_exactly(:user)
    end
  end

  describe "#reverse" do
    subject(:reversed) { keyset.reverse }

    let(:keys) do
      [
        described_class::Key.new(:bumped_at, direction: :desc, nulls_last: true),
        described_class::Key.new(:id),
      ]
    end

    it "walks every key the other way, nulls included" do
      expect(reversed.order).to eq(bumped_at_is_null: :desc, bumped_at: :asc, id: :desc)
    end
  end

  describe "#cursor_for" do
    subject(:cursor) { keyset.cursor_for(record) }

    let(:keys) do
      [
        described_class::Key.new(:bumped_at, direction: :desc, nulls_last: true),
        described_class::Key.new(:id),
      ]
    end
    let(:record) { Topic.new(id: 12, bumped_at: Time.utc(2026, 8, 3, 12)) }

    it "reads one value per key in the order" do
      expect(cursor.values).to eq([0, "2026-08-03T12:00:00.000000Z", 12])
    end

    context "with a null value" do
      let(:record) { Topic.new(id: 12, bumped_at: nil) }

      it "flags the null and leaves the key's own value out of the comparison" do
        expect(cursor.values).to eq([1, nil, 12])
      end
    end
  end

  describe "#project" do
    subject(:projected) { keyset.project(scope) }

    fab!(:topic)

    let(:scope) { Topic.where(id: topic.id) }

    it "leaves a scope whose keys are columns of the table alone" do
      expect(projected).to be(scope)
    end

    context "with a key backed by SQL" do
      let(:keys) do
        [
          described_class::Key.new(:author, sql: "users.username", joins: [:user]),
          described_class::Key.new(:id),
        ]
      end

      it "makes the value readable under the key's name" do
        expect(projected.first.author).to eq(topic.user.username)
      end
    end

    context "with a nullable key" do
      let(:keys) do
        [
          described_class::Key.new(:bumped_at, direction: :desc, nulls_last: true),
          described_class::Key.new(:id),
        ]
      end

      it "makes the null flag readable, so a cursor can be minted for the null tail" do
        expect(projected.first.bumped_at_is_null).to eq(0)
      end
    end
  end
end
