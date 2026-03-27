# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::DataTableColumn do
  fab!(:data_table, :discourse_workflows_data_table)

  subject(:column) do
    described_class.new(data_table: data_table, name: "email", column_type: "string", position: 1)
  end

  it { is_expected.to validate_presence_of(:name) }
  it { is_expected.to validate_presence_of(:column_type) }
  it { is_expected.to validate_presence_of(:position) }
  it { is_expected.to validate_length_of(:name).is_at_most(63) }

  it "accepts valid attributes" do
    expect(column).to be_valid
  end

  it "rejects reserved names" do
    column.name = "id"

    expect(column).not_to be_valid
    expect(column.errors[:name]).to include("is reserved")
  end

  it "rejects invalid types" do
    column.column_type = "unsupported"

    expect(column).not_to be_valid
    expect(column.errors[:column_type]).to include("is not included in the list")
  end
end
