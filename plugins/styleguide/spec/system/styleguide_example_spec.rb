# frozen_string_literal: true

RSpec.describe "Styleguide example card" do
  fab!(:admin)

  let(:styleguide) { PageObjects::Pages::Styleguide.new }
  let(:title) { "<DCharCounter>" }

  before do
    SiteSetting.styleguide_enabled = true
    sign_in(admin)
  end

  it "reveals and hides an example's source" do
    visit "/styleguide/molecules/char-counter"

    expect(styleguide).to have_no_example_source(title)
    expect(styleguide).to have_example_source_expanded(title, false)

    styleguide.toggle_example_source(title)

    # Asserted on an import line rather than the component name: the name appears inside the
    # template too, so it cannot tell `?source=file` output from `?source=template` output,
    # which is the distinction the source loader exists to make. An import can only have come
    # from the whole module.
    expect(styleguide).to have_example_source(
      title,
      text: 'import Component from "@glimmer/component"',
    )
    expect(styleguide).to have_example_source_expanded(title, true)
    expect(styleguide).to have_example_source_wired(title)

    styleguide.toggle_example_source(title)

    expect(styleguide).to have_no_example_source(title)
    expect(styleguide).to have_example_source_expanded(title, false)
  end
end
