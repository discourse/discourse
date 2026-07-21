# frozen_string_literal: true

# TEMPORARY verification of the reported bug. Delete unless kept deliberately.
describe "UiKit | DSelect silent source does not probe" do
  fab!(:admin)

  before do
    SiteSetting.styleguide_enabled = true
    sign_in(admin)
    visit "/styleguide/molecules/select"
  end

  it "settles after one fetch, with no sentinel to trigger another" do
    # The button variant has no text input, so it is opened by clicking the trigger.
    find(".select-examples__async-button .d-combobox__trigger").click

    # The source is deliberately slow (1200ms), so this waits out the first load.
    expect(page).to have_css("[role='listbox'] [role='option']", count: 4, wait: 10)

    # No sentinel means nothing can fire a second fetch, which is what produced the
    # second and third loading placeholders.
    expect(page).to have_no_css("[role='listbox'] .d-combobox__sentinel")
    expect(find("[role='listbox'] [role='option']", match: :first)[:"aria-setsize"]).to eq("4")

    # Well past the 3 x 1200ms the probing version would have taken.
    sleep 4
    expect(page).to have_css("[role='listbox'] [role='option']", count: 4)
    expect(page).to have_no_css(".d-combobox__skeleton")
  end
end
