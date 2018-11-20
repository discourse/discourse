require 'rails_helper'

describe ChildTheme do
  describe "validations" do
    it "doesn't allow children to become parents or parents to become children" do
      theme = Fabricate(:theme)
      child = Fabricate(:theme, component: true)

      child_theme = ChildTheme.new(parent_theme: theme, child_theme: child)
      expect(child_theme.valid?).to eq(true)
      child_theme.save!

      grandchild = Fabricate(:theme, component: true)
      child_theme = ChildTheme.new(parent_theme: child, child_theme: grandchild)
      expect(child_theme.valid?).to eq(false)
      expect(child_theme.errors.full_messages).to contain_exactly(I18n.t("themes.errors.no_multilevels_components"))

      grandparent = Fabricate(:theme)
      child_theme = ChildTheme.new(parent_theme: grandparent, child_theme: theme)
      expect(child_theme.valid?).to eq(false)
      expect(child_theme.errors.full_messages).to contain_exactly(I18n.t("themes.errors.no_multilevels_components"))
    end
  end
end
