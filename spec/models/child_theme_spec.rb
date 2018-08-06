require 'rails_helper'

describe ChildTheme do
  it "doesn't allow a user selectable theme to be a child" do
    parent = Theme.create!(name: "parent", user_id: -1)
    selectable_theme = Theme.create!(name: "selectable", user_id: -1, user_selectable: true)

    relation = ChildTheme.new(parent_theme: parent, child_theme: selectable_theme)
    expect(relation.valid?).to eq(false)
    expect(relation.errors.full_messages).to contain_exactly(I18n.t("themes.errors.component_no_user_selectable"))
  end

  it "doesn't allow a default theme to be child" do
    parent = Theme.create!(name: "parent", user_id: -1)
    default = Theme.create!(name: "selectable", user_id: -1)
    default.set_default!

    relation = ChildTheme.new(parent_theme: parent, child_theme: default)
    expect(relation.valid?).to eq(false)
    expect(relation.errors.full_messages).to contain_exactly(I18n.t("themes.errors.component_no_default"))
  end
end
