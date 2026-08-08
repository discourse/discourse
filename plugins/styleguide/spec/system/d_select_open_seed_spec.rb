# frozen_string_literal: true

# Where the cursor lands when a select-only combobox opens from the keyboard.
#
# APG puts the cursor on an option the moment the list opens — the selected one when there is
# one, the first otherwise — because the reader is told the list expanded and then has nothing
# to be told about. The rendering tests assert exactly that and pass, so this spec exists to
# check the claim somewhere they cannot reach: a real viewport, real CSS heights, and a real
# overlay that renders a frame after the key press rather than inside `settled()`.
describe "UiKit | DSelect open seed" do
  fab!(:admin)

  let(:combobox) { PageObjects::Components::UiKit::DSelect.by_identifier("sg-static") }

  before do
    SiteSetting.styleguide_enabled = true
    sign_in(admin)
    visit "/styleguide/molecules/select?group=start"
    expect(page).to have_css("[data-identifier='sg-static'][data-trigger]")
  end

  # Distinguishes a cursor that was never set from one pointing at an id that does not resolve.
  # Both make `active_option_index` nil, and they call for opposite fixes.
  def active_descendant
    page.evaluate_script(<<~JS)
      (function () {
        const controller = document.querySelector(
          "[data-identifier='sg-static'] [role='combobox'], " +
          "[data-identifier='sg-static'][role='combobox']"
        );
        const id = controller && controller.getAttribute("aria-activedescendant");
        if (!id) {
          return "absent";
        }
        return document.getElementById(id) ? id : "dangling: " + id;
      })()
    JS
  end

  it "puts the cursor on the first option as the list opens" do
    combobox.press_in_controller(:down)

    expect(combobox).to have_listbox
    expect(page).to have_css(combobox.option_selector)

    expect(active_descendant).not_to eq("absent")
    expect(combobox.active_option_index).to eq(0)

    # The symptom a reader reports. A list that opens with no cursor spends the next press
    # landing on row one, so it costs two presses to reach the second option — which reads as
    # navigation that ignores where the list said it was.
    combobox.press_in_controller(:down)

    expect(combobox.active_option_index).to eq(1)
  end
end
