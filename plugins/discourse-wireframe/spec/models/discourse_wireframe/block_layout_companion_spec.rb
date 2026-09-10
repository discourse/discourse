# frozen_string_literal: true

RSpec.describe DiscourseWireframe::BlockLayoutCompanion do
  fab!(:parent) { Fabricate(:theme, name: "Parent") }
  fab!(:component) { Fabricate(:theme, name: "Parent-block-layouts", component: true) }

  def map!
    described_class.create!(parent_theme_id: parent.id, component_theme_id: component.id)
  end

  describe ".companion_id_for" do
    it "returns the mapped component while it is a live child — even with no block_layout field" do
      parent.add_relative_theme!(:child, component)
      map!
      expect(described_class.companion_id_for(parent.id)).to eq(component.id)
    end

    it "still returns it after the component is renamed" do
      parent.add_relative_theme!(:child, component)
      map!
      component.update!(name: "Totally unrelated name")
      expect(described_class.companion_id_for(parent.id)).to eq(component.id)
    end

    it "returns nil once the component is unlinked from the parent" do
      parent.add_relative_theme!(:child, component)
      map!
      parent.update!(child_theme_ids: [])
      expect(described_class.companion_id_for(parent.id)).to be_nil
    end

    it "returns nil when there is no mapping" do
      parent.add_relative_theme!(:child, component)
      expect(described_class.companion_id_for(parent.id)).to be_nil
    end
  end
end
