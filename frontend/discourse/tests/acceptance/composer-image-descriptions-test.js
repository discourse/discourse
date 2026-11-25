import {
  click,
  fillIn,
  triggerKeyEvent,
  visit,
  waitFor,
} from "@ember/test-helpers";
import { test } from "qunit";
import { USER_OPTION_COMPOSITION_MODES } from "discourse/lib/constants";
import { withPluginApi } from "discourse/lib/plugin-api";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

const image = `![original|200x100, 75%](upload://example.png "Image title")`;
const footer = ".d-editor-preview .button-wrapper";
const pencil = '.alt-text-edit-btn[aria-haspopup="dialog"]';

acceptance("Composer - Image Descriptions", function (needs) {
  needs.user({
    "user_option.composition_mode": USER_OPTION_COMPOSITION_MODES.markdown,
  });
  needs.settings({ allow_uncategorized_topics: true });
  needs.pretender((server, helper) => {
    server.post("/uploads/lookup-urls", () =>
      helper.response([
        { short_url: "upload://example.png", url: "/images/avatar.png" },
      ])
    );
  });

  function installDescriptionsOpener() {
    const calls = [];
    withPluginApi((api) => {
      api.registerValueTransformer(
        "composer-image-descriptions-opener",
        () => (args) => calls.push(args)
      );
    });
    return calls;
  }

  test("the native pencil edits only the chosen duplicate after resolving the upload URL", async function (assert) {
    const calls = installDescriptionsOpener();
    await visit("/");
    await click("#create-topic");
    await fillIn(".d-editor-input", `${image}\n\n${image}`);
    await waitFor('.d-editor-preview img[src="/images/avatar.png"]');

    assert.strictEqual(
      calls.length,
      0,
      "rendering the footer does not open the modal"
    );
    await click(`${footer}[data-image-index="1"] ${pencil}`);

    assert.strictEqual(
      calls.length,
      1,
      "clicking the pencil opens the modal once"
    );
    assert.strictEqual(
      calls[0].alt,
      "original",
      "the opener receives the current alt text"
    );
    assert
      .dom(calls[0].image)
      .hasAttribute(
        "data-image-index",
        "1",
        "the opener receives the selected image"
      );
    assert.true(calls[0].onSaveAlt("A | B"), "the second occurrence was saved");
    assert
      .dom(".d-editor-input")
      .hasValue(
        `${image}\n\n![A &#124; B|200x100, 75%](upload://example.png "Image title")`,
        "only the chosen occurrence changed, preserving the dimensions, scale, and title"
      );
  });

  test("rejects an alt callback after the draft changes", async function (assert) {
    const calls = installDescriptionsOpener();
    await visit("/");
    await click("#create-topic");
    await fillIn(".d-editor-input", image);
    await click(`${footer} ${pencil}`);

    const updatedDraft = `${image}\n\n${image}`;
    await fillIn(".d-editor-input", updatedDraft);

    assert.false(
      calls[0].onSaveAlt("New alt"),
      "the callback reports the stale target"
    );
    assert
      .dom(".d-editor-input")
      .hasValue(updatedDraft, "neither occurrence changes");
  });

  test("opens descriptions but does not allow saving alt text when the source is ambiguous", async function (assert) {
    const calls = installDescriptionsOpener();
    await visit("/");
    await click("#create-topic");
    await fillIn(".d-editor-input", `\`\`\`\n${image}\n\`\`\`\n\n${image}`);
    await click(`${footer} ${pencil}`);

    assert.strictEqual(
      calls.length,
      1,
      "the rendered image still opens the modal"
    );
    assert.strictEqual(
      calls[0].onSaveAlt,
      null,
      "the hidden duplicate makes the alt target ambiguous"
    );
  });

  test("keeps the stock alt text, scale, trash, and grid controls with the opener enabled", async function (assert) {
    const calls = installDescriptionsOpener();
    await visit("/");
    await click("#create-topic");
    await fillIn(".d-editor-input", `${image} ${image}`);

    const firstFooter = `${footer}[data-image-index="0"]`;
    assert
      .dom(`${firstFooter} ${pencil} .d-icon-pencil`)
      .exists("uses the stock pencil icon");
    assert
      .dom(`${firstFooter} .alt-text`)
      .hasText("original", "keeps the inline alt text");
    assert
      .dom(`${firstFooter} .scale-btn.active`)
      .hasText("75%", "shows the selected scale");
    assert
      .dom(`${firstFooter} .scale-btn-container`)
      .hasText("100%75%50%", "keeps all three scale buttons");
    assert
      .dom(`${firstFooter} .delete-image-button`)
      .exists("keeps the stock trash control");
    assert
      .dom(`${firstFooter} .wrap-image-grid-button`)
      .exists("keeps the stock grid control for consecutive images");

    await triggerKeyEvent(`${firstFooter} ${pencil}`, "keydown", "Enter");
    assert.strictEqual(
      calls.length,
      1,
      "keyboard activation opens the modal once"
    );
    assert
      .dom(`${firstFooter} .alt-text-edit-container`)
      .isNotVisible("opening descriptions does not activate the inline editor");
  });

  test("keeps the inline alt editor when the opener is disabled", async function (assert) {
    await visit("/");
    await click("#create-topic");
    await fillIn(".d-editor-input", image);

    assert
      .dom(`${footer} ${pencil}`)
      .doesNotExist("the pencil does not advertise a dialog");
    await click(`${footer} .alt-text-edit-btn`);
    assert
      .dom(`${footer} .alt-text-input`)
      .isFocused("the pencil opens the stock inline editor");
  });
});
