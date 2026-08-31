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

    expect(rich).to have_css(".composer-preview-node")

    toolbar.click_show_preview

    expect(rich).to have_css(".composer-preview-node .graphviz-diagram svg")
    expect(rich).to have_no_css(".composer-preview-node.--source")

    toolbar.click_show_source

    expect(rich).to have_css(".composer-preview-node.--source")
  end

  it "keeps the source intact when the diagram is swapped back and forth" do
    compose_diagram

    toolbar.click_show_preview
    toolbar.click_show_source

    composer.toggle_rich_editor

    expect(composer.composer_input.value).to eq("[graphviz]\ndigraph G { a -> b; }\n[/graphviz]")
  end

  it "shows the toolbar only on the diagram the user is working on" do
    compose_diagram

    expect(toolbar).to have_toolbar

    toolbar.click_show_preview
    composer.type_content(:down)

    expect(toolbar).to have_no_toolbar

    rich.find(".composer-preview-node .graphviz-diagram").click

    expect(toolbar).to have_toolbar
  end

  it "opens the diagram full screen from the toolbar" do
    compose_diagram

    toolbar.click_control(fullscreen_control)

    expect(page).to have_css(".d-modal.graphviz-fullscreen .graphviz-diagram svg")
  end

  it "lets the user reach the toolbar from the selected diagram with the keyboard" do
    compose_diagram

    toolbar.click_show_preview
    composer.type_content(:tab)

    expect(toolbar).to have_focused_control(fullscreen_control)
  end
end
