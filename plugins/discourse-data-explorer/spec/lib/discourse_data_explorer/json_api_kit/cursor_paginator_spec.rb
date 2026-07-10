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
end
