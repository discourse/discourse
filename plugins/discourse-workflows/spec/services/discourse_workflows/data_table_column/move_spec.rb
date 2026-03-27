# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::DataTableColumn::Move do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:data_table_id) }
    it { is_expected.to validate_presence_of(:column_id) }
    it { is_expected.to validate_presence_of(:position) }
  end

  describe ".call" do
    subject(:result) { described_class.call(params:) }

    fab!(:data_table) do
      Fabricate(
        :discourse_workflows_data_table,
        columns: [
          { "name" => "first", "type" => "string" },
          { "name" => "second", "type" => "string" },
          { "name" => "third", "type" => "string" },
        ],
      )
    end

    let(:column) { data_table.columns.find_by(name: "third") }
    let(:params) { { data_table_id: data_table.id, column_id: column.id, position: 0 } }

    before { SiteSetting.discourse_workflows_enabled = true }

    context "when everything is ok" do
      it { is_expected.to run_successfully }

      it "reorders positions without changing storage names" do
        result

        expect(data_table.reload.columns.order(:position).map(&:name)).to eq(%w[third first second])
      end
    end
  end
end
