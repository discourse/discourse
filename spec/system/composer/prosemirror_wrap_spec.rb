# frozen_string_literal: true

describe "Composer - ProseMirror - Inline and Block Wrap" do
  include_context "with prosemirror editor"

  it "supports [wrap] to create a wrap block" do
    open_composer
    composer.type_content("[wrap]")

    expect(rich.locator(".composer-wrap-node").filter(visible: true)).not_to have_count(0)

    composer.toggle_rich_editor

    expect(composer).to RSpecPredicates.have_value("[wrap]\n\n[/wrap]\n\n")
  end

  it "supports [wrap=name] to create a named wrap block" do
    open_composer
    composer.type_content("[wrap=example]")

    expect(rich.locator(".composer-wrap-node").filter(visible: true)).not_to have_count(0)

    composer.toggle_rich_editor

    expect(composer).to RSpecPredicates.have_value("[wrap=example]\n\n[/wrap]\n\n")
  end

  it "supports [wrap class=foo] to create a wrap block with attributes" do
    open_composer
    composer.type_content("[wrap class=highlight]")

    expect(rich.locator(".composer-wrap-node").filter(visible: true)).not_to have_count(0)

    composer.toggle_rich_editor

    expect(composer).to RSpecPredicates.have_value("[wrap class=highlight]\n\n[/wrap]\n\n")
  end

  it "creates inline wrap when not at start of line" do
    open_composer
    composer.type_content("Text before [wrap=inline]")

    expect(rich.locator(".composer-wrap-node").filter(visible: true)).not_to have_count(0)
    expect(rich).to contain_text(browser_text_pattern("Text before"), useInnerText: true)
    expect(rich).to contain_text(browser_text_pattern("Wrap content"), useInnerText: true)

    composer.toggle_rich_editor

    expect(composer).to RSpecPredicates.have_value("Text before [wrap=inline]Wrap content[/wrap] ")
  end

  it "opens edit modal when clicking wrap indicator" do
    open_composer
    composer.type_content("[wrap=outer]")

    expect(rich.locator(".composer-wrap-node").filter(visible: true)).not_to have_count(0)

    rich.locator(".d-wrap-indicator").filter(visible: true).click

    expect(browser_root.locator(".wrap-attributes-modal").filter(visible: true)).not_to have_count(
      0,
    )
    expect(
      browser_root
        .locator("input:not(:disabled), textarea:not(:disabled), select:not(:disabled)")
        .and(
          browser_root.locator("[id=#{"name".to_s.to_json}], [name=#{"name".to_s.to_json}]").or(
            browser_root.get_by_label("name", exact: true),
          ),
        )
        .filter(visible: true),
    ).to have_value("outer") # Should show existing wrap name

    browser_root
      .locator("input:not(:disabled), textarea:not(:disabled), select:not(:disabled)")
      .and(
        browser_root.locator("[id=#{"name".to_s.to_json}], [name=#{"name".to_s.to_json}]").or(
          browser_root.get_by_label("name", exact: true),
        ),
      )
      .filter(visible: true)
      .fill("updated")

    browser_root
      .locator("button")
      .filter(visible: true)
      .filter(hasText: browser_text_pattern("Add attribute"))
      .click

    within_browser(browser_root.locator(".wrap-modal__attribute-row").filter(visible: true)) do
      browser_root
        .locator("input:not(:disabled), textarea:not(:disabled), select:not(:disabled)")
        .and(
          browser_root.locator("[id=#{"Key".to_s.to_json}], [name=#{"Key".to_s.to_json}]").or(
            browser_root.get_by_label("Key", exact: true),
          ),
        )
        .filter(visible: true)
        .fill("class")
      browser_root
        .locator("input:not(:disabled), textarea:not(:disabled), select:not(:disabled)")
        .and(
          browser_root.locator("[id=#{"Value".to_s.to_json}], [name=#{"Value".to_s.to_json}]").or(
            browser_root.get_by_label("Value", exact: true),
          ),
        )
        .filter(visible: true)
        .fill("highlight")
    end

    browser_root
      .locator("button")
      .filter(visible: true)
      .filter(hasText: browser_text_pattern("Apply"))
      .click

    expect(rich.locator(".composer-wrap-node").filter(visible: true)).to have_count(1)

    composer.toggle_rich_editor

    expect(composer).to RSpecPredicates.have_value("[wrap=updated class=highlight]\n\n[/wrap]\n\n")
  end

  it "opens edit modal from toolbar when cursor is inside existing wrap" do
    open_composer
    composer.type_content("[wrap=example class=test]")

    expect(rich.locator(".composer-wrap-node").filter(visible: true)).not_to have_count(0)

    rich.locator(".composer-wrap-node").filter(visible: true).click

    browser_root
      .locator("#reply-control .d-editor-button-bar .toolbar__button.options")
      .filter(visible: true)
      .click

    browser_root.locator("[data-name='toggle-wrap']").filter(visible: true).click

    expect(browser_root.locator(".wrap-attributes-modal").filter(visible: true)).not_to have_count(
      0,
    )
    expect(
      browser_root
        .locator("input:not(:disabled), textarea:not(:disabled), select:not(:disabled)")
        .and(
          browser_root.locator("[id=#{"name".to_s.to_json}], [name=#{"name".to_s.to_json}]").or(
            browser_root.get_by_label("name", exact: true),
          ),
        )
        .filter(visible: true),
    ).to have_value("example") # Should show existing wrap name
    expect(
      browser_root
        .locator("input:not(:disabled), textarea:not(:disabled), select:not(:disabled)")
        .and(
          browser_root.locator("[id=#{"Key".to_s.to_json}], [name=#{"Key".to_s.to_json}]").or(
            browser_root.get_by_label("Key", exact: true),
          ),
        )
        .filter(visible: true),
    ).to have_value("class") # Should show existing class attribute
    expect(
      browser_root
        .locator("input:not(:disabled), textarea:not(:disabled), select:not(:disabled)")
        .and(
          browser_root.locator("[id=#{"Value".to_s.to_json}], [name=#{"Value".to_s.to_json}]").or(
            browser_root.get_by_label("Value", exact: true),
          ),
        )
        .filter(visible: true),
    ).to have_value("test")

    browser_root
      .locator("input:not(:disabled), textarea:not(:disabled), select:not(:disabled)")
      .and(
        browser_root.locator("[id=#{"name".to_s.to_json}], [name=#{"name".to_s.to_json}]").or(
          browser_root.get_by_label("name", exact: true),
        ),
      )
      .filter(visible: true)
      .fill("updated")
    browser_root
      .locator("input:not(:disabled), textarea:not(:disabled), select:not(:disabled)")
      .and(
        browser_root.locator("[id=#{"Value".to_s.to_json}], [name=#{"Value".to_s.to_json}]").or(
          browser_root.get_by_label("Value", exact: true),
        ),
      )
      .filter(visible: true)
      .fill("highlight")
    browser_root
      .locator("button")
      .filter(visible: true)
      .filter(hasText: browser_text_pattern("Apply"))
      .click

    expect(rich.locator(".composer-wrap-node").filter(visible: true)).to have_count(1)

    composer.toggle_rich_editor

    expect(composer).to RSpecPredicates.have_value("[wrap=updated class=highlight]\n\n[/wrap]\n\n")
  end
end
