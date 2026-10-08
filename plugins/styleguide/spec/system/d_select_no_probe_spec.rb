# frozen_string_literal: true

# A source that returns a bare array is asserting completeness, so the engine must take the
# first response as the whole set. The regression this guards against was the engine probing for
# a second page anyway, painting a loading placeholder each time.
describe "UiKit | DSelect silent source does not probe" do
  fab!(:admin)

  let(:combobox) { PageObjects::Components::UiKit::DSelect.by_identifier("sg-async-button") }

  before do
    SiteSetting.styleguide_enabled = true
    sign_in(admin)
    visit "/styleguide/molecules/select?group=states"
  end

  it "settles after one fetch, with no sentinel to trigger another" do
    # The button variant has no text input, so it is opened by clicking the trigger.
    combobox.open_trigger

    # The source is deliberately slow (1200ms), so this waits out the first load.
    expect(page).to have_css(combobox.option_selector, count: 4, wait: 10)

    # No sentinel means nothing can fire a second fetch, which is what produced the
    # second and third loading placeholders. Note this is a vacuous negative today — nothing in
    # app code renders a sentinel any more — so it is a guard against reintroducing one, not
    # evidence that the current implementation is correct.
    expect(page).to have_no_css(combobox.in_panel(".d-combobox__sentinel"))
    expect(combobox.options.first[:"aria-setsize"]).to eq("4")

    # Well past the 3 x 1200ms the probing version would have taken.
    sleep 4
    expect(page).to have_css(combobox.option_selector, count: 4)
    expect(page).to have_no_css(combobox.in_panel(".d-combobox__skeleton"))
  end
end
