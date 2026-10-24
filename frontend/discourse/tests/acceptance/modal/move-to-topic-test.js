import { click, fillIn, visit } from "@ember/test-helpers";
import { test } from "qunit";
import { withPluginApi } from "discourse/lib/plugin-api";
import pretender, {
  parsePostData,
  response,
} from "discourse/tests/helpers/create-pretender";
import dSelect from "discourse/tests/helpers/d-select-helper";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";
import selectKit from "discourse/tests/helpers/select-kit-helper";

acceptance("Modal - move-to-topic", function (needs) {
  needs.user({ admin: true });
  needs.site({ can_create_tag: true, can_tag_pms: true });

  test("Transformer can modify merge/move options sent in request", async function (assert) {
    withPluginApi((api) => {
      ["move-to-topic-merge-options", "move-to-topic-move-options"].forEach(
        (transformerName) => {
          api.registerValueTransformer(transformerName, (transformer) => {
            transformer.value.sillyVal = true;
            return transformer.value;
          });
        }
      );
    });

    await visit("/t/internationalization-localization/280");

    // Open admin menu, select a post, and open move to topic modal
    await click(".topic-admin-menu-trigger");
    await click(".topic-admin-menu-content .topic-admin-multi-select button");
    await click(".select-posts .select-post");
    await click(".selected-posts .move-to-topic");

    // Choose existing topic, and pick the first topic.
    await click("input#move-to-existing-topic");
    await fillIn("input#choose-topic-title", 1);
    await click(".choose-topic-list .existing-topic input");

    pretender.post("/t/280/move-posts", (request) => {
      assert.step("request");
      const data = parsePostData(request.requestBody);
      assert.strictEqual(data.sillyVal, "true");
      return response({ success: true });
    });

    // Submit!
    await click(".d-modal__footer .btn-primary");
    assert.verifySteps(["request"]);
  });

  test("sends the chosen tags when moving posts to a new topic", async function (assert) {
    await visit("/t/internationalization-localization/280");
    await click(".topic-admin-menu-trigger");
    await click(".topic-admin-menu-content .topic-admin-multi-select button");
    await click(".select-posts .select-post");
    await click(".selected-posts .move-to-topic");

    await fillIn("#split-topic-name", "A new topic");

    const tags = selectKit(".split-new-topic-form .tag-chooser");
    await tags.expand();
    await tags.selectRowByName("monkey");

    let data;
    pretender.post("/t/280/move-posts", (request) => {
      data = parsePostData(request.requestBody);
      return response({ success: true });
    });

    await click(".d-modal__footer .btn-primary");

    assert.deepEqual(data["tag_ids[]"], ["1"], "sends the chosen tag");
  });

  test("sends the chosen tags when moving posts to a new topic", async function (assert) {
    this.siteSettings.enable_new_select_controls = true;
    await visit("/t/internationalization-localization/280");
    await click(".topic-admin-menu-trigger");
    await click(".topic-admin-menu-content .topic-admin-multi-select button");
    await click(".select-posts .select-post");
    await click(".selected-posts .move-to-topic");

    await fillIn("#split-topic-name", "A new topic");

    assert.dom(".split-new-topic-form .d-select").exists("renders DSelect");
    assert
      .dom(".choose-topic-modal .select-kit.tag-chooser")
      .doesNotExist("replaces the legacy tag chooser");
    await dSelect(".split-new-topic-form .d-select").selectByName("monkey");

    let data;
    pretender.post("/t/280/move-posts", (request) => {
      data = parsePostData(request.requestBody);
      return response({ success: true });
    });

    await click(".d-modal__footer .btn-primary");

    assert.deepEqual(data["tag_ids[]"], ["1"], "sends the chosen tag");
  });

  test("sends the chosen tags when moving posts to a new message", async function (assert) {
    await visit("/t/internationalization-localization/280");
    await click(".topic-admin-menu-trigger");
    await click(".topic-admin-menu-content .topic-admin-multi-select button");
    await click(".select-posts .select-post");
    await click(".selected-posts .move-to-topic");

    await click("#move-to-new-message");
    await fillIn("#split-topic-name", "A new message");

    const tags = selectKit(".choose-topic-modal form .tag-chooser");
    await tags.expand();
    await tags.selectRowByName("monkey");

    let data;
    pretender.post("/t/280/move-posts", (request) => {
      data = parsePostData(request.requestBody);
      return response({ success: true });
    });

    await click(".d-modal__footer .btn-primary");

    assert.strictEqual(
      data.archetype,
      "private_message",
      "moves the posts to a message"
    );
    assert.deepEqual(data["tag_ids[]"], ["1"], "sends the chosen tag");
  });

  test("sends the chosen tags when moving posts to a new message", async function (assert) {
    this.siteSettings.enable_new_select_controls = true;
    await visit("/t/internationalization-localization/280");
    await click(".topic-admin-menu-trigger");
    await click(".topic-admin-menu-content .topic-admin-multi-select button");
    await click(".select-posts .select-post");
    await click(".selected-posts .move-to-topic");

    await click("#move-to-new-message");
    await fillIn("#split-topic-name", "A new message");

    assert.dom(".choose-topic-modal form .d-select").exists("renders DSelect");
    assert
      .dom(".choose-topic-modal .select-kit.tag-chooser")
      .doesNotExist("replaces the legacy tag chooser");
    await dSelect(".choose-topic-modal form .d-select").selectByName("monkey");

    let data;
    pretender.post("/t/280/move-posts", (request) => {
      data = parsePostData(request.requestBody);
      return response({ success: true });
    });

    await click(".d-modal__footer .btn-primary");

    assert.strictEqual(
      data.archetype,
      "private_message",
      "moves the posts to a message"
    );
    assert.deepEqual(data["tag_ids[]"], ["1"], "sends the chosen tag");
  });

  test("sends the chosen tags when moving posts from a message to a new message", async function (assert) {
    await visit("/t/pm-for-testing/12");
    await click(".toggle-admin-menu");
    await click(".topic-admin-multi-select .btn");
    await click("#post_1 .select-post");
    await click(".selected-posts .move-to-topic");

    await fillIn("#split-topic-name", "A new message");

    const tags = selectKit(".choose-topic-modal form .tag-chooser");
    await tags.expand();
    await tags.selectRowByName("monkey");

    let data;
    pretender.post("/t/12/move-posts", (request) => {
      data = parsePostData(request.requestBody);
      return response({ success: true });
    });

    await click(".d-modal__footer .btn-primary");

    assert.strictEqual(
      data.archetype,
      "private_message",
      "moves the posts to a message"
    );
    assert.deepEqual(data["tag_ids[]"], ["1"], "sends the chosen tag");
  });

  test("sends the chosen tags when moving posts from a message to a new message", async function (assert) {
    this.siteSettings.enable_new_select_controls = true;
    await visit("/t/pm-for-testing/12");
    await click(".toggle-admin-menu");
    await click(".topic-admin-multi-select .btn");
    await click("#post_1 .select-post");
    await click(".selected-posts .move-to-topic");

    await fillIn("#split-topic-name", "A new message");

    assert.dom(".choose-topic-modal form .d-select").exists("renders DSelect");
    assert
      .dom(".choose-topic-modal .select-kit.tag-chooser")
      .doesNotExist("replaces the legacy tag chooser");
    await dSelect(".choose-topic-modal form .d-select").selectByName("monkey");

    let data;
    pretender.post("/t/12/move-posts", (request) => {
      data = parsePostData(request.requestBody);
      return response({ success: true });
    });

    await click(".d-modal__footer .btn-primary");

    assert.strictEqual(
      data.archetype,
      "private_message",
      "moves the posts to a message"
    );
    assert.deepEqual(data["tag_ids[]"], ["1"], "sends the chosen tag");
  });
});
