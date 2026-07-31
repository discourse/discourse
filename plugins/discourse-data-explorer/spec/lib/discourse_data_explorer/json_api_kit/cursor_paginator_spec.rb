# frozen_string_literal: true

RSpec.describe DiscourseDataExplorer::JsonApiKit::CursorPaginator do
  subject(:paginator) { described_class.new(scope, order:, size: 2, after:, before:) }

  fab!(:first_query, :query)
  fab!(:second_query, :query)
  fab!(:third_query, :query)
  fab!(:fourth_query, :query)
  fab!(:fifth_query, :query)

  let(:scope) do
    DiscourseDataExplorer::Query.where(
      id: [first_query, second_query, third_query, fourth_query, fifth_query],
    )
  end
  let(:order) { { id: :desc } }
  let(:after) { nil }
  let(:before) { nil }

  def cursor_for(record) = described_class.encode_cursor(record, order:)

  describe ".encode_cursor" do
    it "round-trips through the engine's decoder" do
      expect(Pagy::Keyset.decode(cursor_for(third_query))).to eq([third_query.id])
    end
  end

  context "with neither cursor (first page)" do
    it "returns the newest window" do
      expect(paginator.records).to eq([fifth_query, fourth_query])
    end

    it "has no previous page" do
      expect(paginator.prev_page_params).to be_nil
    end

    it "points the next page after the window's last item" do
      expect(paginator.next_page_params).to eq(after: cursor_for(fourth_query))
    end
  end

  context "with an after cursor mid-list" do
    let(:after) { cursor_for(fourth_query) }

    it "returns the items immediately after the cursor" do
      expect(paginator.records).to eq([third_query, second_query])
    end

    it "points the previous page before the window's first item" do
      expect(paginator.prev_page_params).to eq(before: cursor_for(third_query))
    end

    it "points the next page after the window's last item" do
      expect(paginator.next_page_params).to eq(after: cursor_for(second_query))
    end
  end

  context "with an after cursor near the end" do
    let(:after) { cursor_for(second_query) }

    it "returns the remaining items" do
      expect(paginator.records).to eq([first_query])
    end

    it "has no next page" do
      expect(paginator.next_page_params).to be_nil
    end
  end

  context "with an after cursor on the last item" do
    let(:after) { cursor_for(first_query) }

    it "returns an empty window" do
      expect(paginator.records).to be_empty
    end

    it "still points back at the items before the cursor" do
      expect(paginator.prev_page_params).to eq(before: after)
    end
  end

  context "with a before cursor mid-list" do
    let(:before) { cursor_for(third_query) }

    it "returns the items immediately before the cursor" do
      expect(paginator.records).to eq([fifth_query, fourth_query])
    end

    it "has no previous page" do
      expect(paginator.prev_page_params).to be_nil
    end

    it "points the next page after the window's last item" do
      expect(paginator.next_page_params).to eq(after: cursor_for(fourth_query))
    end
  end

  context "with a before cursor on the first item" do
    let(:before) { cursor_for(fifth_query) }

    it "returns an empty window" do
      expect(paginator.records).to be_empty
    end

    it "still points forward at the items after the cursor" do
      expect(paginator.next_page_params).to eq(after: before)
    end
  end

  context "with a composite order over another column" do
    subject(:paginator) { described_class.new(scope, order:, size: 2, after:) }

    let(:order) { { name: :asc, id: :asc } }
    let(:after) { cursor_for(second_query) }

    before do
      first_query.update!(name: "Zulu")
      second_query.update!(name: "Alpha")
      third_query.update!(name: "Mike")
      fourth_query.update!(name: "Bravo")
      fifth_query.update!(name: "Tango")
    end

    it "paginates along the composite keyset" do
      expect(paginator.records).to eq([fourth_query, third_query])
    end

    it "points the next page after the window's last item" do
      expect(paginator.next_page_params).to eq(after: cursor_for(third_query))
    end
  end

  context "with a nulls-last order over a nullable column" do
    subject(:paginator) do
      described_class.new(scope, order:, size: 2, after:, nulls_last: %i[last_run_at])
    end

    let(:order) { { last_run_at: :desc, id: :desc } }

    let(:maker) { described_class.new(scope, order:, size: 2, nulls_last: %i[last_run_at]) }

    before do
      fifth_query.update!(last_run_at: Time.utc(2026, 7, 5))
      fourth_query.update!(last_run_at: Time.utc(2026, 6, 1))
      third_query.update!(last_run_at: Time.utc(2026, 5, 1))
      # first_query and second_query keep a NULL last_run_at
    end

    context "when reading the first page" do
      it "orders the dated rows first" do
        expect(paginator.records).to eq([fifth_query, fourth_query])
      end
    end

    context "when crossing into the NULL tail" do
      let(:after) { maker.cursor_for(fourth_query) }

      it "returns the last dated row followed by the newest NULL row" do
        expect(paginator.records).to eq([third_query, second_query])
      end
    end

    context "when paginating within the NULL tail" do
      let(:after) { maker.cursor_for(second_query) }

      it "keeps going instead of dead-ending" do
        expect(paginator.records).to eq([first_query])
      end

      it "has no next page" do
        expect(paginator.next_page_params).to be_nil
      end
    end

    context "when walking back from the NULL tail" do
      subject(:paginator) do
        described_class.new(
          scope,
          order:,
          size: 2,
          before: maker.cursor_for(first_query),
          nulls_last: %i[last_run_at],
        )
      end

      it "returns the window immediately before the cursor" do
        expect(paginator.records).to eq([third_query, second_query])
      end
    end
  end

  context "with an invalid cursor" do
    let(:after) { "not-a-cursor!!" }

    it "raises InvalidCursor" do
      expect { paginator }.to raise_error(described_class::InvalidCursor)
    end
  end

  context "with a cursor minted for a different keyset" do
    let(:after) { described_class.encode_cursor(third_query, order: { name: :asc, id: :asc }) }

    it "raises InvalidCursor" do
      expect { paginator }.to raise_error(described_class::InvalidCursor)
    end
  end

  # The shape core PR #36065 uses for `/latest`: ordering values projected as
  # virtual CASE columns (a synthetic priority flag plus a coalesced date), mixed
  # directions, wrapped in a subquery so the outer query can reference them, keyset
  # over the virtual columns. The anchor has to work against THAT to be useful:
  # note the leading column is synthetic, so no client could ever supply a value
  # for it — which is why anchoring resolves a record rather than building a tuple.
  describe "anchoring into a composed virtual-column keyset (core PR #36065 shape)" do
    subject(:window) { described_class.new(wrapped, order: composed_order, size: 2, after: cursor) }

    let(:projected) do
      DiscourseDataExplorer::Query.where(
        id: [first_query, second_query, third_query, fourth_query, fifth_query],
      ).select(
        "*",
        "CASE WHEN hidden THEN 0 ELSE 1 END AS sort_priority",
        "CASE WHEN hidden THEN created_at ELSE last_run_at END AS sort_date",
      )
    end
    let(:wrapped) do
      DiscourseDataExplorer::Query.select("*").from(projected, :data_explorer_queries)
    end
    let(:composed_order) { { sort_priority: :asc, sort_date: :desc, id: :desc } }
    let(:resolver) { described_class.new(wrapped, order: composed_order, size: 1) }
    let(:cursor) { resolver.anchor_cursor { |scope| scope.where(id: third_query.id) } }

    before do
      [
        first_query,
        second_query,
        third_query,
        fourth_query,
        fifth_query,
      ].each_with_index do |query, index|
        query.update!(hidden: index.even?, last_run_at: Time.utc(2026, 7, 10 - index, 12))
      end
    end

    it "starts the window at the anchored record" do
      expect(window.records.first.id).to eq(third_query.id)
    end

    it "keeps the composed ordering across the anchored window" do
      expect(window.records.map(&:sort_priority).uniq.size).to be <= 2
    end

    it "still offers a way back" do
      expect(window.prev_page_params).to be_present
    end

    it "raises when nothing matches the anchor" do
      expect { resolver.anchor_cursor { |scope| scope.where(id: -1) } }.to raise_error(
        described_class::AnchorNotFound,
      )
    end
  end
end
