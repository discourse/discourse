# frozen_string_literal: true

describe "UiKit | DSelect held values that can't be removed" do
  fab!(:admin)

  before do
    SiteSetting.styleguide_enabled = true
    sign_in(admin)
    visit "/styleguide/molecules/select?group=selection"
  end

  def select_for(identifier)
    PageObjects::Components::UiKit::DSelect.by_identifier(identifier)
  end

  it "keeps locked chips through clear" do
    groups = select_for("sg-locked-values")
    expect(groups).to have_locked_value(1)
    expect(groups).to have_locked_value(2)

    groups.clear
    expect(groups).to have_selected_value("1,2")
  end

  it "shows a locked item in a capped field's strip" do
    groups = select_for("sg-locked-strip")
    groups.open
    expect(groups).to have_locked_value(1)
  end

  it "locks a group in the group picker" do
    groups = select_for("sg-locked-groups")
    expect(groups).to have_locked_value("staff")
  end
end
