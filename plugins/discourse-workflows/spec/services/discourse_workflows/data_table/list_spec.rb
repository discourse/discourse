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
      it "returns an empty page" do
        expect(result).to run_successfully
        expect(result[:data_tables]).to be_empty
        expect(result[:total_rows]).to eq(0)
        expect(result[:load_more_url]).to be_nil
        expect(result[:table_stats]).to eq({})
      end
    end

    context "when there are data tables" do
      fab!(:data_table_a) { Fabricate(:discourse_workflows_data_table, name: "Alpha") }
      fab!(:data_table_b) { Fabricate(:discourse_workflows_data_table, name: "Bravo") }

      it "returns all data tables ordered by id descending" do
        expect(result).to run_successfully
        expect(result[:data_tables].map(&:id)).to eq([data_table_b.id, data_table_a.id])
        expect(result[:total_rows]).to eq(2)
        expect(result[:load_more_url]).to be_nil
        expect(result[:table_stats].keys).to contain_exactly(data_table_a.id, data_table_b.id)
      end
    end

    context "with pagination" do
      fab!(:data_table_1) { Fabricate(:discourse_workflows_data_table, name: "First") }
      fab!(:data_table_2) { Fabricate(:discourse_workflows_data_table, name: "Second") }
      fab!(:data_table_3) { Fabricate(:discourse_workflows_data_table, name: "Third") }

      let(:params) { { limit: 2 } }

      it "returns the first page with statistics and a next-page cursor" do
        expect(result).to run_successfully
        expect(result[:data_tables].map(&:id)).to eq([data_table_3.id, data_table_2.id])
        expect(result[:total_rows]).to eq(3)
        expect(result[:table_stats].keys).to contain_exactly(data_table_3.id, data_table_2.id)
        expect(result[:load_more_url]).to eq(
          "/admin/plugins/discourse-workflows/data-tables.json?cursor=#{data_table_2.id}&limit=2",
        )
      end

      context "when using a cursor" do
        let(:params) { { limit: 2, cursor: data_table_2.id } }

        it "returns the final page after the cursor" do
          expect(result).to run_successfully
          expect(result[:data_tables].map(&:id)).to eq([data_table_1.id])
          expect(result[:total_rows]).to eq(3)
          expect(result[:table_stats].keys).to eq([data_table_1.id])
          expect(result[:load_more_url]).to be_nil
        end
      end
    end
  end
end
