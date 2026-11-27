# frozen_string_literal: true

describe "Composer - ProseMirror - code block previews" do
  include_context "with prosemirror editor"

  fab!(:theme)

  let(:toolbar) { PageObjects::Components::ComposerPreviewToolbar.new }

  before do
    theme.set_field(
      target: :extra_js,
      type: :js,
      name: "discourse/api-initializers/register-code-block-preview.gjs",
      value: <<~JS,
        import { apiInitializer } from "discourse/lib/api";

        const Preview = <template>
          <div class="test-code-block-preview">rendered {{@source}}</div>
        </template>;

        export default apiInitializer((api) => {
          api.registerRichEditorExtension({
            codeBlockPreviews: { mermaid: Preview },
          });
        });
      JS
    )
    theme.save!
    SiteSetting.default_theme_id = theme.id
  end

  def compose_preview_between_paragraphs
    open_composer
    composer.type_content("before\n\n")
    composer.type_content("```hidden source")

    expect(rich).to have_css("pre code", text: "hidden source")

    # a registered preview's language is offered by the selector even though
    # highlight.js does not know it
    rich.find("pre .code-language-select").find("option", text: "mermaid").select_option

    toolbar.click_show_preview

    expect(rich).to have_css(".test-code-block-preview", text: "hidden source")
    expect(rich).to have_no_css("pre")

    composer.send_keys(:down)
    composer.type_content("after")
    rich.find("p", text: "after") # settle before measuring drag targets
  end

  def center_of(selector, text: nil)
    rich.find(selector, text: text).evaluate_script(
      "(({ x, y, width, height }) => [x + width / 2, y + height / 2])(this.getBoundingClientRect())",
    )
  end

  # while the block previews, its source has no DOM a selection could enter:
  # a selection swept across it must take the block whole, never place text
  # inside the hidden source
  it "keeps a mouse-drag selection out of the hidden source" do
    compose_preview_between_paragraphs

    from_x, from_y = center_of("p", text: "before")
    over_x, over_y = center_of(".test-code-block-preview")
    to_x, to_y = center_of("p", text: "after")

    page.driver.with_playwright_page do |pw_page|
      pw_page.mouse.move(from_x, from_y)
      pw_page.mouse.down
      pw_page.mouse.move(over_x, over_y, steps: 5)
      pw_page.mouse.move(to_x, to_y, steps: 5)
      pw_page.mouse.up
    end

    composer.type_content("REPLACED")
    composer.toggle_rich_editor

    value = composer.composer_input.value
    expect(value).to include("REPLACED")
    expect(value).not_to include("hidden source")
    expect(value).not_to include("```")
    expect(value).not_to include("\n")
  end

  it "keeps a shift-click range selection out of the hidden source" do
    compose_preview_between_paragraphs

    rich.find("p", text: "before").click
    rich.find("p", text: "after").click(:shift)

    composer.send_keys(:backspace)
    composer.toggle_rich_editor

    value = composer.composer_input.value
    expect(value).not_to include("hidden source")
    expect(value).not_to include("```")
    expect(value).not_to include("\n")
  end

  it "replaces the whole block within a select-all" do
    compose_preview_between_paragraphs

    composer.select_all
    composer.type_content("REPLACED")
    composer.toggle_rich_editor

    expect(composer).to have_value("REPLACED")
  end
end
