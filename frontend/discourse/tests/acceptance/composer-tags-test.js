import { click, currentURL, fillIn, visit } from "@ember/test-helpers";
import { test } from "qunit";
import Category from "discourse/models/category";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import {
  acceptance,
  updateCurrentUser,
} from "discourse/tests/helpers/qunit-helpers";
import selectKit from "discourse/tests/helpers/select-kit-helper";
import { i18n } from "discourse-i18n";

acceptance("Composer - Tags", function (needs) {
  needs.user();
  needs.pretender((server, helper) => {
    server.post("/uploads/lookup-urls", () => {
      return helper.response([]);
    });
  });
  needs.site({ can_tag_topics: true });
  needs.settings({ allow_uncategorized_topics: true });

  test("staff bypass tag validation rule", async function (assert) {
    await visit("/");
    await click("#create-topic");

    await fillIn("#reply-title", "this is my new topic title");
    await fillIn(".d-editor-input", "this is the *content* of a post");

    Category.findById(2).set("minimum_required_tags", 1);

    const categoryChooser = selectKit(".category-chooser");
    await categoryChooser.expand();
    await categoryChooser.selectRowByValue(2);

    await click("#reply-control button.create");
    assert.notStrictEqual(currentURL(), "/");
  });

  test("filterTags filters out staff tags from URL parameters for non-staff users", async function (assert) {
    updateCurrentUser({ moderator: false, admin: false });

    pretender.get("/tags/list", () => {
      return response({
        list_tags: [
          { id: "public", name: "public", staff: false },
          { id: "staff", name: "staff", staff: true },
        ],
      });
    });

    await visit("/new-topic?tags=public,staff");

    const tagChooser = selectKit(".mini-tag-chooser");
    assert.strictEqual(
      tagChooser.header().value(),
      "public",
      "staff tag is filtered out for non-staff user"
    );
  });

  test("filterTags does not filter out staff tags for staff users", async function (assert) {
    updateCurrentUser({ moderator: true, admin: false });

    pretender.get("/tags/list", () => {
      return response({
        list_tags: [
          { id: "public", name: "public", staff: false },
          { id: "staff", name: "staff", staff: true },
        ],
      });
    });

    await visit("/new-topic?tags=public,staff");

    const tagChooser = selectKit(".mini-tag-chooser");
    assert.strictEqual(
      tagChooser.header().value(),
      "public,staff",
      "staff tag is NOT filtered out for staff user"
    );
  });

  test("users do not bypass tag validation rule", async function (assert) {
    await visit("/");
    await click("#create-topic");

    await fillIn("#reply-title", "this is my new topic title");
    await fillIn(".d-editor-input", "this is the *content* of a post");

    Category.findById(2).set("minimum_required_tags", 1);

    const categoryChooser = selectKit(".category-chooser");
    await categoryChooser.expand();
    await categoryChooser.selectRowByValue(2);

    updateCurrentUser({ moderator: false, admin: false, trust_level: 1 });

    await click("#reply-control button.create");
    assert.strictEqual(currentURL(), "/");
    assert
      .dom(".popup-tip.bad")
      .hasText(
        i18n("composer.error.tags_missing", { count: 1 }),
        "it should display the right alert"
      );

    const tags = selectKit(".mini-tag-chooser");
    await tags.expand();
    await tags.selectRowByName("monkey");

    await click("#reply-control button.create");
    assert.notStrictEqual(currentURL(), "/");
  });

  test("users do not bypass min required tags in tag group validation rule", async function (assert) {
    await visit("/");
    await click("#create-topic");

    await fillIn("#reply-title", "this is my new topic title");
    await fillIn(".d-editor-input", "this is the *content* of a post");

    Category.findById(2).setProperties({
      required_tag_groups: [{ name: "support tags", min_count: 1 }],
    });

    const categoryChooser = selectKit(".category-chooser");
    await categoryChooser.expand();
    await categoryChooser.selectRowByValue(2);

    updateCurrentUser({ moderator: false, admin: false, trust_level: 1 });

    await click("#reply-control button.create");
    assert.strictEqual(currentURL(), "/");
    assert
      .dom(".popup-tip.bad")
      .hasText(
        i18n("composer.error.tags_missing", { count: 1 }),
        "it should display the right alert"
      );

    const tags = selectKit(".mini-tag-chooser");
    await tags.expand();
    await tags.selectRowByName("monkey");

    await click("#reply-control button.create");
    assert.notStrictEqual(currentURL(), "/");
  });

  test("users who cannot tag PMs do not see the selector", async function (assert) {
    await visit("/u/charlie");
    await click("button.compose-pm");

    assert.dom(".composer-fields .mini-tag-chooser").doesNotExist();
  });
});

acceptance("Composer - Tags (PMs)", function (needs) {
  needs.user();
  needs.pretender((server, helper) => {
    server.post("/uploads/lookup-urls", () => {
      return helper.response([]);
    });
  });
  needs.site({ can_tag_topics: true, can_tag_pms: true });

  test("users who can tag PMs see the selector", async function (assert) {
    await visit("/u/charlie");
    await click("button.compose-pm");

    assert.dom(".composer-fields .mini-tag-chooser").exists();
  });
});
