import { getOwner } from "@ember/owner";
import {
  click,
  currentURL,
  fillIn,
  settled,
  triggerKeyEvent,
  visit,
} from "@ember/test-helpers";
import { test } from "qunit";
import loadAccessibleName from "discourse/lib/load-accessible-name";
import Category from "discourse/models/category";
import Composer from "discourse/models/composer";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import dSelect from "discourse/tests/helpers/d-select-helper";
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

acceptance("Composer - Tags (new select controls)", function (needs) {
  needs.user();
  needs.pretender((server, helper) => {
    server.post("/uploads/lookup-urls", () => helper.response([]));
    server.get("/tags/list", () =>
      helper.response({
        list_tags: [
          { id: "public", name: "public", staff: false },
          { id: "other", name: "other", staff: false },
        ],
      })
    );
  });
  needs.site({ can_tag_topics: true, can_create_tag: true });
  needs.settings({
    allow_uncategorized_topics: true,
    tagging_enabled: true,
    enable_new_select_controls: true,
  });

  test("the composer renders the DSelect tag chooser", async function (assert) {
    await visit("/");
    await click("#create-topic");

    assert.dom(".tags-input .d-select.mini-tag-chooser").exists();
    assert.dom(".tags-input .select-kit").doesNotExist();
  });

  test("picking a tag writes the composer's tags", async function (assert) {
    await visit("/");
    await click("#create-topic");
    await dSelect(".tags-input .d-select").selectByName("monkey");

    const tags = getOwner(this).lookup("service:composer").model.tags;
    assert.deepEqual(
      tags.map((tag) => (typeof tag === "string" ? tag : tag.name)),
      ["monkey"]
    );
    assert.strictEqual(tags[0].id, 1, "a server tag keeps its id");
  });

  test("a created tag is written as a new tag", async function (assert) {
    await visit("/");
    await click("#create-topic");
    await dSelect(".tags-input .d-select").search("brandnew");
    await triggerKeyEvent(".tags-input [role='combobox']", "keydown", "Enter");

    const tags = getOwner(this).lookup("service:composer").model.tags;
    assert.deepEqual(tags, [{ id: "brandnew", name: "brandnew", isNew: true }]);
  });

  test("tags from the URL show as held names", async function (assert) {
    await visit("/new-topic?tags=public");

    assert.dom(".tags-input .d-select").hasAttribute("data-name", "public");
  });

  test("the tag field is named Tags, and its placeholder carries the requirement", async function (assert) {
    const nameOf = await loadAccessibleName();
    await visit("/");
    await click("#create-topic");
    const input = ".tags-input [role='combobox']";

    assert.strictEqual(nameOf(document.querySelector(input)), "Tags");
    assert
      .dom(input)
      .hasAttribute("placeholder", i18n("tagging.choose_for_topic"));

    Category.findById(2).set("minimum_required_tags", 1);
    getOwner(this).lookup("service:composer").model.set("categoryId", 2);
    await settled();

    assert.strictEqual(nameOf(document.querySelector(input)), "Tags");
    assert
      .dom(input)
      .hasAttribute(
        "placeholder",
        i18n("tagging.choose_for_topic_required", { count: 1 })
      );
  });
});

/** The draft data the composer would save: its tags and category. */
function draftTagsAndCategory(owner) {
  const { tags, categoryId } = owner
    .lookup("service:composer")
    .model.serializeDraftData();
  return { tags, categoryId };
}

/** Opens a new-topic draft holding tags and a category, as reopening a saved draft does. */
async function openDraft(owner, draft) {
  await owner.lookup("service:composer").open({
    action: Composer.CREATE_TOPIC,
    draftKey: "new_topic",
    draftSequence: 0,
    draft: JSON.stringify({
      action: Composer.CREATE_TOPIC,
      archetypeId: "regular",
      title: "A draft from the other mode",
      reply: "Its body",
      ...draft,
    }),
  });
}

const SAVED = {
  tags: [{ id: 1, name: "monkey" }, { name: "brandnew" }],
  categoryId: 2,
};

acceptance(
  "Composer - Tags and category in both select modes",
  function (needs) {
    needs.user();
    needs.site({ can_tag_topics: true, can_create_tag: true });
    needs.settings({ allow_uncategorized_topics: true, tagging_enabled: true });

    test("the legacy controls save an existing tag, a new tag and a category", async function (assert) {
      this.siteSettings.enable_new_select_controls = false;
      await visit("/");
      await click("#create-topic");

      const tags = selectKit(".mini-tag-chooser");
      await tags.expand();
      await tags.selectRowByName("monkey");
      await tags.fillInFilter("brandnew");
      await tags.selectRowByValue("brandnew");
      const category = selectKit(".category-chooser");
      await category.expand();
      await category.selectRowByValue(2);

      assert.deepEqual(draftTagsAndCategory(getOwner(this)), SAVED);
    });

    test("the new controls save the same draft data", async function (assert) {
      this.siteSettings.enable_new_select_controls = true;
      await visit("/");
      await click("#create-topic");

      await dSelect(".tags-input .d-select").selectByName("monkey");
      await dSelect(".tags-input .d-select").search("brandnew");
      await triggerKeyEvent(
        ".tags-input [role='combobox']",
        "keydown",
        "Enter"
      );
      await dSelect(".category-input .d-select").select(2);

      assert.deepEqual(draftTagsAndCategory(getOwner(this)), SAVED);
    });

    test("the legacy controls reopen a draft and keep its tags", async function (assert) {
      this.siteSettings.enable_new_select_controls = false;
      await visit("/");
      await openDraft(getOwner(this), SAVED);

      assert.strictEqual(
        selectKit(".mini-tag-chooser").header().name(),
        "monkey,brandnew",
        "the held tags show"
      );
      assert.strictEqual(selectKit(".category-chooser").header().value(), "2");

      const tags = selectKit(".mini-tag-chooser");
      await tags.expand();
      await tags.selectRowByName("gazelle");

      assert.deepEqual(draftTagsAndCategory(getOwner(this)), {
        tags: [...SAVED.tags, { id: 2, name: "gazelle" }],
        categoryId: 2,
      });
    });

    test("the new controls reopen a draft and keep its tags", async function (assert) {
      this.siteSettings.enable_new_select_controls = true;
      await visit("/");
      await openDraft(getOwner(this), SAVED);

      assert
        .dom(".tags-input .d-select")
        .hasAttribute("data-name", "monkey,brandnew", "the held tags show");
      assert.dom(".category-input .d-select").hasAttribute("data-value", "2");

      await dSelect(".tags-input .d-select").selectByName("gazelle");

      assert.deepEqual(draftTagsAndCategory(getOwner(this)), {
        tags: [...SAVED.tags, { id: 2, name: "gazelle" }],
        categoryId: 2,
      });
    });
  }
);

acceptance("Composer - Tags (compact on mobile)", function (needs) {
  needs.user();
  needs.mobileView();
  needs.pretender((server, helper) => {
    server.post("/uploads/lookup-urls", () => helper.response([]));
    server.get("/tags/list", () =>
      helper.response({
        list_tags: [
          { id: "public", name: "public", staff: false },
          { id: "other", name: "other", staff: false },
        ],
      })
    );
  });
  needs.site({ can_tag_topics: true });
  needs.settings({
    allow_uncategorized_topics: true,
    tagging_enabled: true,
    enable_new_select_controls: true,
    enable_composer_redesign: true,
  });

  test("the redesigned composer shows a tag count on mobile", async function (assert) {
    await visit("/new-topic?tags=public,other");

    assert.dom(".tags-input .d-select__chips-more").hasText("2");
    assert.dom(".tags-input .d-select__trigger .d-select__chip").doesNotExist();
  });
});
