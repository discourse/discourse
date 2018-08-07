require 'rails_helper'

describe ChildTheme do
  describe "validations" do
    it "doesn't allow children to become parents or parents to become children" do
      theme = Fabricate(:theme)
      child = Fabricate(:theme)

      child_theme = ChildTheme.new(parent_theme: theme, child_theme: child)
      expect(child_theme.valid?).to eq(true)
      child_theme.save!

      grandchild = Fabricate(:theme)
      child_theme = ChildTheme.new(parent_theme: child, child_theme: grandchild)
      expect(child_theme.valid?).to eq(false)
      expect(child_theme.errors.full_messages).to contain_exactly(I18n.t("themes.errors.no_multilevels_components"))

      grandparent = Fabricate(:theme)
      child_theme = ChildTheme.new(parent_theme: grandparent, child_theme: theme)
      expect(child_theme.valid?).to eq(false)
      expect(child_theme.errors.full_messages).to contain_exactly(I18n.t("themes.errors.no_multilevels_components"))
    end

    it "doesn't allow a user selectable theme to be a child" do
      parent = Fabricate(:theme)
      selectable_theme = Fabricate(:theme, user_selectable: true)

      child_theme = ChildTheme.new(parent_theme: parent, child_theme: selectable_theme)
      expect(child_theme.valid?).to eq(false)
      expect(child_theme.errors.full_messages).to contain_exactly(I18n.t("themes.errors.component_no_user_selectable"))
    end

    it "doesn't allow a default theme to be child" do
      parent = Fabricate(:theme)
      default = Fabricate(:theme)
      default.set_default!

      child_theme = ChildTheme.new(parent_theme: parent, child_theme: default)
      expect(child_theme.valid?).to eq(false)
      expect(child_theme.errors.full_messages).to contain_exactly(I18n.t("themes.errors.component_no_default"))
    end
  end
end
