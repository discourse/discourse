# frozen_string_literal: true

describe "Edit graphviz in the rich editor" do
  include_context "with prosemirror editor"

  let(:toolbar) { PageObjects::Components::ComposerPreviewToolbar.new }
  let(:fullscreen_control) { "composer-preview-toolbar__graphviz-fullscreen" }

  before { SiteSetting.discourse_graphviz_enabled = true }

  def compose_diagram
    open_composer
    composer.type_content("[graphviz]")
    composer.type_content("digraph G { a -> b; }")
  end

  it "lets the user swap a diagram between its source and the drawing" do
    compose_diagram

    expect(toolbar).to have_toolbar

    toolbar.click_show_preview

    expect(rich).to have_css(".composer-preview-node .graphviz-diagram svg")
    expect(rich).to have_no_css(".composer-preview-node.--source")

    composer.type_content(:down)

    expect(toolbar).to have_no_toolbar

    rich.find(".composer-preview-node .graphviz-diagram").click
    toolbar.click_show_source

    expect(rich).to have_css(".composer-preview-node.--source")
  end

  it "lets the user open the diagram full screen from the keyboard" do
    compose_diagram

    toolbar.click_show_preview
    composer.type_content(:tab)

    expect(toolbar).to have_focused_control(fullscreen_control)

    page.send_keys(:enter)

    expect(page).to have_css(".d-modal.graphviz-fullscreen .graphviz-diagram svg")
  end
end
