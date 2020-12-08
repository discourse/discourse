import {
  acceptance,
  updateCurrentUser,
} from "discourse/tests/helpers/qunit-helpers";
import { click, currentURL, fillIn, visit } from "@ember/test-helpers";
import Category from "discourse/models/category";
import selectKit from "discourse/tests/helpers/select-kit-helper";
import { test } from "qunit";

acceptance("Composer - Tags", function (needs) {
  needs.user();
  needs.pretender((server, helper) => {
    server.post("/uploads/lookup-urls", () => {
      return helper.response([]);
    });
  });
  needs.site({ can_tag_topics: true });

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
    assert.notEqual(currentURL(), "/");
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
    assert.equal(currentURL(), "/");

    const tags = selectKit(".mini-tag-chooser");
    await tags.expand();
    await tags.selectRowByValue("monkey");

    await click("#reply-control button.create");
    assert.notEqual(currentURL(), "/");
  });
});
