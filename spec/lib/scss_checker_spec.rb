# frozen_string_literal: true

RSpec.describe Stylesheet::Manager::ScssChecker do
  fab!(:theme) { Fabricate(:theme) }

  describe "#has_scss" do
    it "should return true when theme has scss" do
      scss_theme = Fabricate(:theme, component: true)
      scss_theme.set_field(target: :common, name: "scss", value: ".scss{color: red;}")
      scss_theme.save!

      embedded_scss_theme = Fabricate(:theme, component: true)
      embedded_scss_theme.set_field(
        target: :common,
        name: "embedded_scss",
        value: ".scss{color: red;}",
      )
      embedded_scss_theme.save!

      theme_ids = [scss_theme.id, embedded_scss_theme.id]

      desktop_theme_checker = described_class.new(:desktop_theme, theme_ids)

      expect(desktop_theme_checker.has_scss(scss_theme.id)).to eq(true)
      expect(desktop_theme_checker.has_scss(embedded_scss_theme.id)).to eq(false)

      embedded_theme_checker = described_class.new(:embedded_theme, theme_ids)

      expect(embedded_theme_checker.has_scss(scss_theme.id)).to eq(false)
      expect(embedded_theme_checker.has_scss(embedded_scss_theme.id)).to eq(true)
    end

    it "should return false when theme does not have scss" do
      expect(described_class.new(:desktop_theme, [theme.id]).has_scss(theme.id)).to eq(false)
    end
  end
end
