# frozen_string_literal: true

describe AdminDashboardSection do
  before { described_class.delete_all }

  it "requires a section_id" do
    expect(described_class.new(position: 0, visible: true)).not_to be_valid
  end

  it "requires a position" do
    expect(described_class.new(section_id: "highlights", visible: true)).not_to be_valid
  end

  it "enforces a unique section_id" do
    described_class.create!(section_id: "highlights", position: 0, visible: true)

    expect {
      described_class.create!(section_id: "highlights", position: 1, visible: true)
    }.to raise_error(ActiveRecord::RecordInvalid)
  end

  it "is valid with all attributes" do
    expect(described_class.new(section_id: "highlights", position: 0, visible: false)).to be_valid
  end
end
