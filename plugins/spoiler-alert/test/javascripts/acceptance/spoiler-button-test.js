import { click, fillIn, visit } from "@ember/test-helpers";
import { test } from "qunit";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";
import selectKit from "discourse/tests/helpers/select-kit-helper";
import { i18n } from "discourse-i18n";

acceptance("Spoiler Button", function (needs) {
  needs.user();
  needs.settings({ spoiler_enabled: true });

  test("spoiler button", async (assert) => {
    const popUpMenu = selectKit(".toolbar-popup-menu-options");

    await visit("/");

    assert.dom("#create-topic").exists("the create button is visible");

    await click("#create-topic");
    const categoryChooser = selectKit(".category-chooser");
    await categoryChooser.expand();
    await categoryChooser.selectRowByValue(2);
    await popUpMenu.expand();
    await popUpMenu.selectRowByName(i18n("spoiler.title"));

    assert
      .dom(".d-editor-input")
      .hasValue(
        `[spoiler]${i18n("composer.spoiler_text")}[/spoiler]`,
        "contains the right output"
      );

    assert
      .dom(".d-editor-input")
      .hasProperty(
        "selectionStart",
        9,
        "starts highlighting at the right position"
      );
    assert
      .dom(".d-editor-input")
      .hasProperty(
        "selectionEnd",
        i18n("composer.spoiler_text").length + 9,
        "ends highlighting at the right position"
      );

    await fillIn(".d-editor-input", "This is hidden");

    const textarea = document.querySelector(".d-editor-input");
    textarea.selectionStart = 0;
    textarea.selectionEnd = textarea.value.length;

    await popUpMenu.expand();
    await popUpMenu.selectRowByName(i18n("spoiler.title"));

    assert
      .dom(".d-editor-input")
      .hasValue(
        `[spoiler]This is hidden[/spoiler]`,
        "contains the right output"
      );

    assert
      .dom(".d-editor-input")
      .hasProperty(
        "selectionStart",
        9,
        "starts highlighting at the right position"
      );
    assert
      .dom(".d-editor-input")
      .hasProperty(
        "selectionEnd",
        23,
        "ends highlighting at the right position"
      );

    await fillIn(".d-editor-input", "Before this is hidden After");

    textarea.selectionStart = 7;
    textarea.selectionEnd = 21;

    await popUpMenu.expand();
    await popUpMenu.selectRowByName(i18n("spoiler.title"));

    assert
      .dom(".d-editor-input")
      .hasValue(
        `Before [spoiler]this is hidden[/spoiler] After`,
        "contains the right output"
      );

    assert
      .dom(".d-editor-input")
      .hasProperty(
        "selectionStart",
        16,
        "starts highlighting at the right position"
      );
    assert
      .dom(".d-editor-input")
      .hasProperty(
        "selectionEnd",
        30,
        "ends highlighting at the right position"
      );

    await fillIn(".d-editor-input", "Before\nthis is hidden\nAfter");

    textarea.selectionStart = 7;
    textarea.selectionEnd = 21;

    await popUpMenu.expand();
    await popUpMenu.selectRowByName(i18n("spoiler.title"));

    assert
      .dom(".d-editor-input")
      .hasValue(
        `Before\n[spoiler]this is hidden[/spoiler]\nAfter`,
        "contains the right output"
      );

    assert
      .dom(".d-editor-input")
      .hasProperty(
        "selectionStart",
        16,
        "starts highlighting at the right position"
      );
    assert
      .dom(".d-editor-input")
      .hasProperty(
        "selectionEnd",
        30,
        "ends highlighting at the right position"
      );

    // enforce block mode when selected text is multiline
    await fillIn(".d-editor-input", "Before\nthis is\n\nhidden\nAfter");

    textarea.selectionStart = 7;
    textarea.selectionEnd = 22;

    await popUpMenu.expand();
    await popUpMenu.selectRowByName(i18n("spoiler.title"));

    assert
      .dom(".d-editor-input")
      .hasValue(
        `Before\n[spoiler]\nthis is\n\nhidden\n[/spoiler]\nAfter`,
        "contains the right output"
      );

    assert
      .dom(".d-editor-input")
      .hasProperty(
        "selectionStart",
        17,
        "starts highlighting at the right position"
      );
    assert
      .dom(".d-editor-input")
      .hasProperty(
        "selectionEnd",
        32,
        "ends highlighting at the right position"
      );
  });
});
