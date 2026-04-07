# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::DataTable::List do
  describe described_class::Contract, type: :model do
    subject(:contract) { described_class.new(limit:, cursor:) }

    let(:limit) { nil }
    let(:cursor) { nil }

    it "is always valid" do
      expect(contract).to be_valid
    end

    describe "#normalized_limit" do
      context "when limit is not provided" do
        it "returns the default limit" do
          contract.valid?
          expect(contract.normalized_limit).to eq(
            DiscourseWorkflows::DataTable::List::DEFAULT_LIMIT,
          )
        end
      end

      context "when limit is provided" do
        let(:limit) { 10 }

        it "returns the provided limit" do
          contract.valid?
          expect(contract.normalized_limit).to eq(10)
        end
      end

      context "when limit exceeds maximum" do
        let(:limit) { 999 }

        it "clamps to maximum" do
          contract.valid?
          expect(contract.normalized_limit).to eq(DiscourseWorkflows::DataTable::List::MAX_LIMIT)
        end
      end

      context "when limit is below minimum" do
        let(:limit) { 0 }

        it "clamps to 1" do
          contract.valid?
          expect(contract.normalized_limit).to eq(1)
        end
      end
    end
  end

  describe ".call" do
    subject(:result) { described_class.call(params:) }

    let(:params) { {} }

    before { SiteSetting.discourse_workflows_enabled = true }

    context "when there are no data tables" do
      it { is_expected.to run_successfully }

      it "returns an empty collection" do
        expect(result[:data_tables]).to be_empty
      end

      it "returns zero total rows" do
        expect(result[:total_rows]).to eq(0)
      end

      it "does not return a load more url" do
        expect(result[:load_more_url]).to be_nil
      end

      it "returns empty table sizes" do
        expect(result[:table_sizes]).to eq({})
      end
    end

    context "when there are data tables" do
      fab!(:data_table_a) { Fabricate(:discourse_workflows_data_table, name: "Alpha") }
      fab!(:data_table_b) { Fabricate(:discourse_workflows_data_table, name: "Bravo") }

      it { is_expected.to run_successfully }

      it "returns data tables ordered by id descending" do
        expect(result[:data_tables].map(&:id)).to eq([data_table_b.id, data_table_a.id])
      end

      it "returns the total count" do
        expect(result[:total_rows]).to eq(2)
      end

      it "does not return a load more url when all results fit" do
        expect(result[:load_more_url]).to be_nil
      end

      it "returns table sizes keyed by data table id" do
        expect(result[:table_sizes].keys).to contain_exactly(data_table_a.id, data_table_b.id)
      end

      it "returns columns from catalog introspection" do
        result
        columns = result[:data_tables].first.columns
        expect(columns.map { |c| c["name"] }).to include("value")
      end
    end

    context "with pagination" do
      let(:params) { { limit: 2 } }

      fab!(:data_table_1) { Fabricate(:discourse_workflows_data_table, name: "First") }
      fab!(:data_table_2) { Fabricate(:discourse_workflows_data_table, name: "Second") }
      fab!(:data_table_3) { Fabricate(:discourse_workflows_data_table, name: "Third") }

      it "returns only the requested number of data tables" do
        expect(result[:data_tables].size).to eq(2)
      end

      it "returns a load more url with cursor" do
        last_id = result[:data_tables].last.id
        expect(result[:load_more_url]).to eq(
          "/admin/plugins/discourse-workflows/data-tables.json?cursor=#{last_id}&limit=2",
        )
      end

      it "returns the total count of all data tables" do
        expect(result[:total_rows]).to eq(3)
      end

      it "returns table sizes only for returned data tables" do
        expect(result[:table_sizes].keys.size).to eq(2)
      end

      context "when using a cursor" do
        let(:params) { { limit: 2, cursor: data_table_3.id } }

        it "returns data tables after the cursor" do
          expect(result[:data_tables].map(&:id)).to eq([data_table_2.id, data_table_1.id])
        end

        it "does not return a load more url when no more results" do
          expect(result[:load_more_url]).to be_nil
        end
      end
    end

    context "when limit is below minimum" do
      fab!(:data_table_1) { Fabricate(:discourse_workflows_data_table, name: "First") }
      fab!(:data_table_2) { Fabricate(:discourse_workflows_data_table, name: "Second") }

      let(:params) { { limit: 0 } }

      it "clamps limit to 1" do
        expect(result[:data_tables].length).to eq(1)
      end
    end
  end
end
