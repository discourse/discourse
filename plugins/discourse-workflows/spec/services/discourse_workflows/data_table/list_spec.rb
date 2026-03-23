# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::DataTable::List do
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
    end

    context "when there are data tables" do
      fab!(:data_table_a, :discourse_workflows_data_table) do
        Fabricate(:discourse_workflows_data_table, name: "Alpha")
      end
      fab!(:data_table_b, :discourse_workflows_data_table) do
        Fabricate(:discourse_workflows_data_table, name: "Bravo")
      end

      it { is_expected.to run_successfully }

      it "returns data tables ordered by id descending" do
        expect(result[:data_tables].map(&:id)).to eq([data_table_b.id, data_table_a.id])
      end

      it "returns the total count" do
        expect(result[:total_rows]).to eq(2)
      end
    end

    context "with pagination" do
      let(:params) { { limit: 2 } }

      fab!(:data_table_1, :discourse_workflows_data_table) do
        Fabricate(:discourse_workflows_data_table, name: "First")
      end
      fab!(:data_table_2, :discourse_workflows_data_table) do
        Fabricate(:discourse_workflows_data_table, name: "Second")
      end
      fab!(:data_table_3, :discourse_workflows_data_table) do
        Fabricate(:discourse_workflows_data_table, name: "Third")
      end

      it "returns only the requested number of data tables" do
        expect(result[:data_tables].size).to eq(2)
      end

      it "returns a load more url with cursor" do
        last_id = result[:data_tables].last.id
        expect(result[:load_more_url]).to eq(
          "/admin/plugins/discourse-workflows/data-tables.json?cursor=#{last_id}&limit=2",
        )
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
  end
end
