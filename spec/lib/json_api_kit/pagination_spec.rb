# frozen_string_literal: true

# Properties of a whole listing: that the pages read from an order, in either direction, agree
# with the order's own SQL. They span the order, the comparison and the pages, so no single
# class's spec can state them.
RSpec.describe JsonApiKit::Pagination do
  # Two groups sharing a created_at, each mixing rows that have a pinned_at with rows that do
  # not, so a null sits in the middle of the listing rather than at its end.
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
  let(:order) { described_class::Order.for(keyset) }
  let(:topics) do
    [first_pinned, first_unpinned, second_pinned, second_unpinned, third_unpinned, third_pinned]
  end
  let(:scope) { Topic.where(id: topics.map(&:id)) }

  # What the order asks the database for, which is what paging through it has to reproduce.
  let(:listing) { scope.order(keyset.order).pluck(:id) }

  let(:walked) do
    [].tap do |ids|
      cursor = nil

      loop do
        page = described_class::Paginator.for(scope, order:, size: 2, after: cursor)
        ids.concat(page.records.map(&:id))
        cursor = page.next
        break if cursor.nil?
      end
    end
  end

  # Every row of a listing can be paged from, so every row can be paged back from too.
  let(:rows) do
    described_class::Paginator.for(scope, order:, size: listing.size).rows.index_by { it.record.id }
  end
  let(:read_before_each_row) do
    listing.map do
      described_class::Paginator
        .for(scope, order:, size: 2, before: rows[it].cursor)
        .records
        .map(&:id)
    end
  end
  let(:two_rows_before_each) { listing.each_index.map { listing[[it - 2, 0].max...it] } }

  context "with a nullable key that does not lead" do
    let(:keys) do
      [
        key.new(:created_at, model:),
        key.new(:pinned_at, model:, nulls: :last),
        key.new(:id, model:),
      ]
    end

    it "walks the whole listing forwards" do
      expect(walked).to eq(listing)
    end

    it "reads the rows before every row of the listing" do
      expect(read_before_each_row).to eq(two_rows_before_each)
    end
  end

  context "with a nullable leading key" do
    let(:keys) { [key.new(:pinned_at, model:, nulls: :last), key.new(:id, model:)] }

    it "walks the whole listing forwards" do
      expect(walked).to eq(listing)
    end

    it "reads the rows before every row of the listing" do
      expect(read_before_each_row).to eq(two_rows_before_each)
    end
  end

  context "with a leading key whose nulls sort first" do
    let(:keys) { [key.new(:pinned_at, model:, nulls: :first), key.new(:id, model:)] }

    it "walks the whole listing forwards" do
      expect(walked).to eq(listing)
    end

    it "reads the rows before every row of the listing" do
      expect(read_before_each_row).to eq(two_rows_before_each)
    end
  end
end
