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

  it { is_expected.to delegate_method(:valued_condition).to(:leading) }
  it { is_expected.to delegate_method(:null_condition).to(:leading) }
  it { is_expected.to delegate_method(:nulls_read_first?).to(:leading) }

  describe ".new" do
    context "when there is no key" do
      let(:keys) { [] }

      it "refuses to build the keyset" do
        expect { keyset }.to raise_error(ArgumentError)
      end
    end

    context "when the same key appears twice" do
      let(:keys) do
        [
          described_class::Key.new(:id, model:, direction: :desc),
          described_class::Key.new(:created_at, model:),
          described_class::Key.new(:id, model:),
        ]
      end

      it "keeps the first of the two" do
        expect(keyset.keys).to eq(keys.take(2))
      end
    end
  end

  describe "#leading" do
    subject(:leading) { keyset.leading }

    it "returns the key the listing reads first" do
      expect(leading.name).to eq(:created_at)
    end
  end

  describe "#rest" do
    subject(:rest) { keyset.rest }

    it "returns the keyset behind the leading key" do
      expect(rest.keys.map(&:name)).to eq([:id])
    end

    context "when no key follows the leading key" do
      let(:keys) { [described_class::Key.new(:created_at, model:)] }

      it "refuses to build the keyset" do
        expect { rest }.to raise_error(ArgumentError)
      end
    end
  end

  describe "#split?" do
    context "when the leading key cannot be null" do
      it { is_expected.not_to be_split }
    end

    context "when the leading key can be null" do
      let(:keys) do
        [
          described_class::Key.new(:bumped_at, model:, nulls: :last),
          described_class::Key.new(:id, model:),
        ]
      end

      it { is_expected.to be_split }
    end
  end

  describe "#without_nulls" do
    subject(:without_nulls) { keyset.without_nulls }

    let(:keys) do
      [
        described_class::Key.new(:bumped_at, model:, direction: :desc, nulls: :last),
        described_class::Key.new(:id, model:),
      ]
    end

    it "returns a keyset whose leading key cannot be null" do
      expect(without_nulls.leading).not_to be_nullable
    end

    it "keeps the keys behind the leading one" do
      expect(without_nulls.keys.drop(1)).to eq(keys.drop(1))
    end
  end

  describe "#columns" do
    subject(:columns) { keyset.columns }

    it "returns the column every key reads" do
      expect(columns).to eq(%i[created_at id])
    end

    context "when a key carries its own SQL" do
      let(:keys) do
        [
          described_class::Key.new(:author, model:, sql: "users.username", joins: [:user]),
          described_class::Key.new(:id, model:),
        ]
      end

      it "leaves that key out" do
        expect(columns).to eq([:id])
      end
    end
  end

  describe "#order" do
    before { keys.each { allow(it).to receive(:ordering).and_return("#{it.name} ordering") } }

    it "orders by every key, in sequence" do
      expect(keyset.order).to eq(["created_at ordering", "id ordering"])
    end
  end

  describe "#cursor_for" do
    subject(:cursor) { keyset.cursor_for(record) }

    let(:record) { Topic.new(id: 12, created_at: Time.utc(2026, 8, 3, 12)) }
    let(:expected_cursor) { JsonApiKit::Pagination::Cursor.new([record.created_at, record.id]) }

    it "returns one value for each key, in sequence" do
      expect(cursor).to eq(expected_cursor)
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

    it "returns each join once" do
      expect(joins).to contain_exactly(:user)
    end
  end

  describe "#reverse" do
    let(:keys) do
      [
        described_class::Key.new(:bumped_at, model:, direction: :desc, nulls: :last),
        described_class::Key.new(:id, model:),
      ]
    end

    before { keys.each { allow(it).to receive(:reverse).and_call_original } }

    it "reverses every one of its keys" do
      keyset.reverse

      expect(keys).to all(have_received(:reverse))
    end
  end

  describe "#compatible_with?" do
    let(:cursor) { JsonApiKit::Pagination::Cursor.new([Time.utc(2026, 8, 3, 12), 12]) }

    it "accepts the cursor" do
      expect(keyset).to be_compatible_with(cursor:)
    end

    context "when the cursor holds fewer values than the keyset compares" do
      let(:cursor) { JsonApiKit::Pagination::Cursor.new([12]) }

      it "refuses the cursor" do
        expect(keyset).not_to be_compatible_with(cursor:)
      end
    end
  end

  describe "#project" do
    subject(:projected_scope) { keyset.project(scope) }

    fab!(:topic)

    let(:scope) { Topic.where(id: topic.id) }

    context "when no key carries its own SQL" do
      it "returns the same scope" do
        expect(projected_scope).to be(scope)
      end
    end

    context "when a key carries its own SQL" do
      let(:keys) do
        [
          described_class::Key.new(:author, model:, sql: "users.username", joins: [:user]),
          described_class::Key.new(:id, model:),
        ]
      end

      it "reads the value of that SQL under the name of the key" do
        expect(projected_scope.first.author).to eq(topic.user.username)
      end
    end

    context "when a key is nullable" do
      let(:keys) do
        [
          described_class::Key.new(:bumped_at, model:, direction: :desc, nulls: :last),
          described_class::Key.new(:id, model:),
        ]
      end

      it "returns the same scope" do
        expect(projected_scope).to be(scope)
      end
    end
  end
end
