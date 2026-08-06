# frozen_string_literal: true

RSpec.describe JsonApiKit::Pagination::Keyset do
  subject(:keyset) { described_class.new(keys) }

  let(:model) { Topic }
  let(:keys) do
    [
      described_class::Key.new(:created_at, model:, direction: :desc),
      described_class::Key.new(:id, model:),
    ]
  end

  describe ".new" do
    context "without a single key" do
      let(:keys) { [] }

      it "refuses to build an order out of nothing" do
        expect { keyset }.to raise_error(ArgumentError)
      end
    end
  end

  describe "#leading" do
    subject(:leading) { keyset.leading }

    it "is the key the order is read by first" do
      expect(leading.name).to eq(:created_at)
    end
  end

  describe "#rest" do
    subject(:rest) { keyset.rest }

    it "is the order behind the leading key" do
      expect(rest.keys.map(&:name)).to eq([:id])
    end

    context "with nothing behind the leading key" do
      let(:keys) { [described_class::Key.new(:created_at, model:)] }

      it "refuses to be an order of nothing" do
        expect { rest }.to raise_error(ArgumentError)
      end
    end
  end

  describe "#splits?" do
    it "reads a listing whose leading key always has a value as one band" do
      expect(keyset).not_to be_splits
    end

    context "when the leading key can be null" do
      let(:keys) do
        [
          described_class::Key.new(:bumped_at, model:, nulls: :last),
          described_class::Key.new(:id, model:),
        ]
      end

      it "splits it, the rows it is null in belonging to a band of their own" do
        expect(keyset).to be_splits
      end
    end
  end

  describe "#valued" do
    subject(:valued) { keyset.valued }

    let(:keys) do
      [
        described_class::Key.new(:bumped_at, model:, direction: :desc, nulls: :last),
        described_class::Key.new(:id, model:),
      ]
    end

    it "reads the leading key as one that cannot be null" do
      expect(valued.leading).not_to be_nullable
    end

    it "leaves the keys behind it as they are, nulls and all" do
      expect(valued.keys.drop(1)).to eq(keys.drop(1))
    end
  end

  describe "#order" do
    subject(:order) { keyset.order.map(&:to_s) }

    it "orders by every key, each its own way" do
      expect(order).to eq([%("topics"."created_at" DESC), %("topics"."id" ASC)])
    end

    context "with a key already in the order" do
      let(:keys) do
        [
          described_class::Key.new(:id, model:, direction: :desc),
          described_class::Key.new(:created_at, model:),
          described_class::Key.new(:id, model:),
        ]
      end

      it "keeps the first place the key takes" do
        expect(order).to eq([%("topics"."id" DESC), %("topics"."created_at" ASC)])
      end
    end
  end

  describe "#cursor_for" do
    subject(:cursor) { keyset.cursor_for(record) }

    let(:record) { Topic.new(id: 12, created_at: Time.utc(2026, 8, 3, 12)) }

    it "carries one value per key, in the order's own sequence" do
      expect(cursor.values).to eq(["2026-08-03T12:00:00.000000Z", 12])
    end
  end

  describe "#joins" do
    subject(:joins) { keyset.joins }

    let(:keys) do
      [
        described_class::Key.new(:username, model:, sql: "users.username", joins: [:user]),
        described_class::Key.new(:title, model:, sql: "topics.title", joins: [:user]),
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
        described_class::Key.new(:bumped_at, model:, direction: :desc, nulls: :last),
        described_class::Key.new(:id, model:),
      ]
    end

    it "walks every one of its keys the other way" do
      expect(reversed.keys.map { it.direction.to_sym }).to eq(%i[asc desc])
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
          described_class::Key.new(:author, model:, sql: "users.username", joins: [:user]),
          described_class::Key.new(:id, model:),
        ]
      end

      it "makes the value readable under the key's name" do
        expect(projected.first.author).to eq(topic.user.username)
      end
    end

    context "with a nullable key, which is a plain column like any other" do
      let(:keys) do
        [
          described_class::Key.new(:bumped_at, model:, direction: :desc, nulls: :last),
          described_class::Key.new(:id, model:),
        ]
      end

      it "leaves the scope alone, nullability needing nothing projected" do
        expect(projected).to be(scope)
      end
    end
  end
end
