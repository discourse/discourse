import { on } from "@ember/modifier";
import {
  click,
  fillIn,
  find,
  render,
  settled,
  waitFor,
  waitUntil,
} from "@ember/test-helpers";
import { module, test } from "qunit";
import sinon from "sinon";
import ModalContainer from "discourse/components/modal-container";
import DToasts from "discourse/float-kit/components/d-toasts";
import Toasts from "discourse/float-kit/services/toasts";
import { EDIT } from "discourse/models/composer";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import { i18n } from "discourse-i18n";

const trigger = ".test-open-image-descriptions";
const submit = ".image-descriptions-modal .d-modal__footer [type=submit]";
const alt = '.image-descriptions-modal input[type="text"][name="alt"]';
const description = '.image-descriptions-modal textarea[name="description"]';
const captionResponse = (text) =>
  response({ captions: [{ base62_sha1: "abc123", description: text }] });

module("Integration | Component | ImageDescriptionsModal", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    this.owner.register("service:toasts", Toasts);
    this.siteSettings.discourse_ai_enabled = true;
    this.siteSettings.ai_post_image_captions_enabled = true;
    this.composer = this.owner.lookup("service:composer");
    this.composer.model = {
      action: EDIT,
      post: { id: 42, post_type: this.site.post_types.regular },
    };
  });

  async function renderControl(owner, onSaveAlt, originalAlt = "A cat") {
    const editor = owner.lookup("service:post-image-caption-editor");
    const open = () =>
      editor.open({
        alt: originalAlt,
        image: { dataset: { base62Sha1: "abc123" } },
        onSaveAlt,
      });
    await render(
      <template>
        <button
          class="test-open-image-descriptions"
          type="button"
          {{on "click" open}}
        >Open</button>
        <ModalContainer />
        <DToasts />
      </template>
    );
  }

  test("load preserves edits to alt text and seeds the caption before Apply is enabled", async function (assert) {
    let pending;
    pretender.get(
      "/discourse-ai/post-image-captions/42",
      (request) => {
        pending = request;
        return captionResponse("An AI caption");
      },
      true
    );
    pretender.put("/discourse-ai/post-image-captions/42/abc123", () => {
      assert.step("saved caption");
      return response({});
    });
    await renderControl(this.owner, (value) => assert.step(value));
    const opening = click(trigger);
    await waitFor(alt);
    await waitUntil(() => pending);
    assert
      .dom(submit)
      .isDisabled(
        "Apply waits for the initial caption to be written into the form"
      );
    const typing = fillIn(alt, "Draft alt text");
    await waitUntil(() => find(alt)?.value === "Draft alt text");
    pretender.resolve(pending);
    await Promise.all([opening, typing]);

    assert
      .dom(alt)
      .hasValue("Draft alt text", "caption load does not overwrite alt edits");
    assert
      .dom(description)
      .hasValue("An AI caption", "the caption field is seeded after loading");
    await click(submit);
    assert.verifySteps(
      ["Draft alt text"],
      "an untouched caption is not submitted"
    );
  });

  test("reopening gets the current caption rather than the previous modal's value", async function (assert) {
    let caption = "Original caption";
    pretender.get("/discourse-ai/post-image-captions/42", () =>
      captionResponse(caption)
    );
    await renderControl(this.owner, null);
    await click(trigger);
    assert
      .dom(alt)
      .hasAttribute(
        "readonly",
        "",
        "alt text is read-only without an editor callback"
      );
    assert.dom(description).hasValue(caption, "opens with the stored caption");
    await click(".image-descriptions-modal .d-modal-cancel");

    caption = "Caption changed elsewhere";
    await click(trigger);
    assert
      .dom(description)
      .hasValue(caption, "fetches a fresh caption when reopened");
  });

  test("whitespace-only changes do not save either description", async function (assert) {
    pretender.get("/discourse-ai/post-image-captions/42", () =>
      captionResponse("  An AI caption  ")
    );
    pretender.put("/discourse-ai/post-image-captions/42/abc123", () => {
      assert.step("saved caption");
      return response({});
    });
    await renderControl(
      this.owner,
      () => assert.step("saved alt text"),
      "  A\n cat "
    );
    await click(trigger);
    await fillIn(alt, "A cat");
    await fillIn(description, "   An AI caption    ");
    await click(submit);
    assert.verifySteps([], "neither value changed after normalization");
  });

  test("a declined core alt save does not announce success", async function (assert) {
    pretender.get("/discourse-ai/post-image-captions/42", () =>
      response({ captions: [] })
    );
    const announce = sinon.spy(this.owner.lookup("service:a11y"), "announce");
    await renderControl(this.owner, () => false);
    await click(trigger);
    await fillIn(alt, "New alt text");
    await click(submit);

    assert.false(
      announce.calledWith(
        i18n("discourse_ai.post_image_captions.image_descriptions.alt_updated")
      ),
      "does not announce an update that did not happen"
    );
    assert
      .dom(".image-descriptions-modal__notice")
      .hasText(
        i18n(
          "discourse_ai.post_image_captions.image_descriptions.alt_not_updated"
        ),
        "provides feedback when the draft update is declined"
      );
    assert
      .dom(alt)
      .hasValue("New alt text", "keeps the unsaved alt text available to copy");
  });

  test("a caption response from a changed composer does not apply alt text or announce success", async function (assert) {
    let pending;
    pretender.get("/discourse-ai/post-image-captions/42", () =>
      captionResponse("An AI caption")
    );
    pretender.put(
      "/discourse-ai/post-image-captions/42/abc123",
      (request) => {
        pending = request;
        return response({ base62_sha1: "abc123", description: "New caption" });
      },
      true
    );
    await renderControl(this.owner, () => assert.step("saved alt text"));
    await click(trigger);
    await fillIn(alt, "New alt text");
    await fillIn(description, "New caption");
    const saving = click(submit);
    await waitUntil(() => pending);
    this.composer.model = { ...this.composer.model };
    pretender.resolve(pending);
    await saving;
    await settled();

    assert.verifySteps(
      [],
      "the alt callback is skipped after the composer changes"
    );
    assert
      .dom(".fk-d-default-toast__message")
      .doesNotExist("the stale caption response does not show a success toast");
    assert
      .dom(".image-descriptions-modal")
      .doesNotExist("the stale modal closes");
  });
});
