# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::DataTable::List do
  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:admin)

    let(:params) { {} }
    let(:dependencies) { { guardian: admin.guardian } }

    context "when user cannot manage workflows" do
      fab!(:user)

      let(:dependencies) { { guardian: user.guardian } }

      it { is_expected.to fail_a_policy(:can_manage_workflows) }
    end

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
  end
end
