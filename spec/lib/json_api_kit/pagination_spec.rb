# frozen_string_literal: true

RSpec.describe JsonApiKit::Pagination do
  fab!(:first_pinned) do
    Fabricate(:topic, created_at: Time.utc(2026, 8, 1), pinned_at: Time.utc(2026, 7, 1))
  end
  fab!(:first_unpinned) { Fabricate(:topic, created_at: Time.utc(2026, 8, 1), pinned_at: nil) }
  fab!(:second_pinned) do
    Fabricate(:topic, created_at: Time.utc(2026, 8, 1), pinned_at: Time.utc(2026, 7, 2))
  end
  fab!(:second_unpinned) { Fabricate(:topic, created_at: Time.utc(2026, 8, 1), pinned_at: nil) }
  fab!(:third_unpinned) { Fabricate(:topic, created_at: Time.utc(2026, 8, 2), pinned_at: nil) }
  fab!(:third_pinned) do
    Fabricate(:topic, created_at: Time.utc(2026, 8, 2), pinned_at: Time.utc(2026, 7, 3))
  end

  let(:model) { Topic }
  let(:key) { described_class::Keyset::Key }
  let(:keyset) { described_class::Keyset.new(keys) }
  let(:order) { described_class::Order.new(keyset) }
  let(:topics) do
    [first_pinned, first_unpinned, second_pinned, second_unpinned, third_unpinned, third_pinned]
  end
  let(:scope) { Topic.where(id: topics.map(&:id)) }
  let(:listing) { scope.order(keyset.order).pluck(:id) }

  let(:paged_ids) do
    [].tap do |ids|
      cursor = nil

      loop do
        page = described_class::Paginator.for(scope, order:, size: 2, after: cursor)
        ids.concat(page.rows.map { it.record.id })
        cursor = page.next
        break if cursor.nil?
      end
    end
  end

  let(:rows) do
    described_class::Paginator.for(scope, order:, size: listing.size).rows.index_by { it.record.id }
  end
  let(:read_before_each_row) do
    listing.map do
      described_class::Paginator
        .for(scope, order:, size: 2, before: rows[it].cursor)
        .rows
        .map { it.record.id }
    end
  end
  let(:two_rows_before_each) { listing.each_index.map { listing[[it - 2, 0].max...it] } }

  context "when a nullable key does not lead" do
    let(:keys) do
      [
        key.new(:created_at, model:),
        key.new(:pinned_at, model:, nulls: :last),
        key.new(:id, model:),
      ]
    end

    it "reads the whole listing, one page at a time" do
      expect(paged_ids).to eq(listing)
    end

    it "reads the two rows before every row of the listing" do
      expect(read_before_each_row).to eq(two_rows_before_each)
    end
  end

  context "when the leading key is nullable" do
    let(:keys) { [key.new(:pinned_at, model:, nulls: :last), key.new(:id, model:)] }

    it "reads the whole listing, one page at a time" do
      expect(paged_ids).to eq(listing)
    end

    it "reads the two rows before every row of the listing" do
      expect(read_before_each_row).to eq(two_rows_before_each)
    end
  end

  context "when the leading key sorts its nulls first" do
    let(:keys) { [key.new(:pinned_at, model:, nulls: :first), key.new(:id, model:)] }

    it "reads the whole listing, one page at a time" do
      expect(paged_ids).to eq(listing)
    end

    it "reads the two rows before every row of the listing" do
      expect(read_before_each_row).to eq(two_rows_before_each)
    end
  end
end
