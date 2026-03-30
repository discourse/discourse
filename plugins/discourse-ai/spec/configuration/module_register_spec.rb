# frozen_string_literal: true

describe DiscourseAi::Configuration::Module do
  before { SiteSetting.data_explorer_enabled = true }

  describe ".all with filtered registry" do
    it "includes modules registered via the AI features registry" do
      all_modules = described_class.all
      de_mod = all_modules.find { |m| m.name == :data_explorer }
      expect(de_mod).to be_present
      expect(de_mod.features.map(&:name)).to include("query_generation")
    end

    it "groups multiple features under the same module" do
      all_modules = described_class.all
      de_modules = all_modules.select { |m| m.name == :data_explorer }
      expect(de_modules.size).to eq(1)
    end
  end
end
