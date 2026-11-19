# frozen_string_literal: true

RSpec.describe DiscourseWireframe::BlockLayoutCompanion do
  fab!(:parent) { Fabricate(:theme, name: "Parent") }
  fab!(:component) { Fabricate(:theme, name: "Parent-block-layouts", component: true) }

  before { SiteSetting.wireframe_enabled = true }

  def map!
    described_class
      .create!(parent_theme_id: parent.id, component_theme_id: component.id)
      .tap { Theme::ManagedComponentIds.reset }
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

  describe "managed components" do
    it "marks designs as managed so the themes page hides them" do
      map!
      expect(component.managed_component?).to eq(true)
      expect(Fabricate(:theme, component: true).managed_component?).to eq(false)
    end
  end

  describe ".all_designs" do
    fab!(:second_parent) { Fabricate(:theme, name: "Second") }

    before { map! }

    it "lists no themes for a design that is not installed" do
      design = described_class.all_designs.find { _1[:id] == component.id }
      expect(design).to include(themes: [], active: false)
    end

    it "lists every theme the design is installed on" do
      parent.add_relative_theme!(:child, component)
      second_parent.add_relative_theme!(:child, component)

      design = described_class.all_designs.find { _1[:id] == component.id }
      expect(design[:themes].map { _1[:name] }).to contain_exactly("Parent", "Second")
      expect(design[:active]).to eq(true)
    end
  end
end
