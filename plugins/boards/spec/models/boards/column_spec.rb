# frozen_string_literal: true

RSpec.describe Boards::Column do
  fab!(:admin)

  before { enable_current_plugin }

  fab!(:board) { Boards::Board.create!(name: "Test", slug: "test-column", created_by_id: admin.id) }

  it "defaults to priority sorting" do
    column = board.columns.create!(title: "Backlog", position: 0)

    expect(column.default_sort).to eq("priority")
    expect(column).to be_priority
  end

  it "supports recency sorting" do
    column = board.columns.create!(title: "Done", position: 0, default_sort: "recency")

    expect(column.default_sort).to eq("recency")
    expect(column).to be_recency
  end

  describe "icons" do
    after { SvgSprite.expire_cache }

    it "adds icons in use to the SVG sprite" do
      board.columns.create!(title: "Backlog", position: 0, icon: "blender")

      expect(SvgSprite.all_icons).to include("blender")
    end

    it "expires the sprite cache when an icon changes" do
      column = board.columns.create!(title: "Backlog", position: 0, icon: "blender")

      expect(SvgSprite.all_icons).to include("blender")

      column.update!(icon: "guitar")

      expect(SvgSprite.all_icons).to include("guitar")
      expect(SvgSprite.all_icons).not_to include("blender")
    end
  end

  it "accepts a bare hex or no color, but rejects malformed values" do
    expect(board.columns.build(title: "A", position: 0, color: "1A2B3C")).to be_valid
    expect(board.columns.build(title: "B", position: 1, color: "f0a")).to be_valid
    expect(board.columns.build(title: "C", position: 2, color: nil)).to be_valid

    # Stored without a leading "#", and the old named keys are no longer valid.
    expect(board.columns.build(title: "D", position: 3, color: "#1A2B3C")).not_to be_valid
    expect(board.columns.build(title: "E", position: 4, color: "purple")).not_to be_valid
  end
end
