# frozen_string_literal: true

# Proves the property every other DSelect system spec now depends on: a page object scoped by
# `@identifier` reads ONLY its own overlay.
#
# Without this, the scoping is untested by construction — the other specs open one select at a
# time, so a document-global selector and a correctly-scoped one behave identically and both
# pass. The failure this guards against is silent: a global lookup reading a *different* open
# panel and asserting happily against it.
describe "UiKit | DSelect identifier scoping" do
  fab!(:admin)

  let(:opened) { PageObjects::Components::UiKit::DSelect.by_identifier("sg-multi") }
  let(:other) { PageObjects::Components::UiKit::DSelect.by_identifier("sg-default") }

  before do
    SiteSetting.styleguide_enabled = true
    sign_in(admin)
    visit "/styleguide/molecules/select?group=start"
    expect(page).to have_css("[data-identifier='sg-multi'][data-trigger]")
  end

  it "reads only its own overlay while another select is closed" do
    opened.open

    expect(opened.options.size).to be > 0
    expect(opened.listbox).to be_present

    # The load-bearing assertion. Before scoping, `options` was
    # `all("[role='listbox'] [role='option']")` — document-global — so this select, whose panel
    # is shut, would have reported the *other* select's rows.
    expect(other.options.size).to eq(0)
    expect(other.narrow_hint?).to eq(false)
  end

  it "reports focus only for its own instance" do
    opened.open
    expect(opened.input_focused?).to eq(true)

    # Focus is genuinely inside `sg-multi`'s input. A predicate that only checked for "some
    # focused .d-combobox__input on the page" would wrongly answer true here too. Asserted
    # through the absence matcher so it settles immediately instead of waiting out the timeout
    # that a negative `input_focused?` would.
    expect(other.input_blurred?).to eq(true)
  end

  it "rejects an identifier that could break out of a selector" do
    expect {
      PageObjects::Components::UiKit::DSelect.by_identifier("sg-x'] , [data-content")
    }.to raise_error(ArgumentError, /unsafe DSelect identifier/)
  end
end
