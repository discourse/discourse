import { getOwner } from "@ember/owner";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import domFromString from "discourse/lib/dom-from-string";
import { helperContext } from "discourse/lib/helpers";
import {
  categoryBadgeHTML,
  categoryLinkHTML,
  defaultCategoryLinkRenderer,
  replaceCategoryLinkRenderer,
} from "discourse/ui-kit/helpers/d-category-link";

module("Unit | Utility | category-badge", function (hooks) {
  setupTest(hooks);

  test("categoryBadge without a category", function (assert) {
    assert.blank(categoryBadgeHTML(), "returns no HTML");
  });

  test("regular categoryBadge", function (assert) {
    const store = getOwner(this).lookup("service:store");
    const category = store.createRecord("category", {
      name: "hello",
      id: 123,
      description_text: "cool description",
      color: "ff0",
      text_color: "f00",
    });
    const tag = domFromString(categoryBadgeHTML(category))[0];

    assert.strictEqual(tag.tagName, "A", "creates a `a` wrapper tag");
    assert.strictEqual(
      tag.className.trim(),
      "badge-category__wrapper",
      "has the correct class"
    );

    const label = tag.children[0];
    assert
      .dom(label)
      .doesNotHaveAttribute(
        "title",
        "does not expose the description as a tooltip"
      );
    assert.dom(label.children[0]).hasText("hello", "has the category name");
  });

  test("undefined color", function (assert) {
    const store = getOwner(this).lookup("service:store");
    const noColor = store.createRecord("category", { name: "hello", id: 123 });
    const tag = domFromString(categoryBadgeHTML(noColor))[0];

    assert.blank(
      tag.attributes["style"],
      "has no color style because there are no colors"
    );
  });

  test("topic count", function (assert) {
    const store = getOwner(this).lookup("service:store");
    const category = store.createRecord("category", { name: "hello", id: 123 });

    assert.false(
      categoryBadgeHTML(category).includes("topic-count"),
      "does not include topic count by default"
    );
    assert.true(
      categoryBadgeHTML(category, { topicCount: 20 }).indexOf("topic-count") >
        20,
      "is included when specified"
    );
  });

  test("allowUncategorized", function (assert) {
    const store = getOwner(this).lookup("service:store");
    const uncategorized = store.createRecord("category", {
      name: "uncategorized",
      id: 345,
    });

    const { site } = helperContext();
    site.set("uncategorized_category_id", 345);

    assert.blank(
      categoryBadgeHTML(uncategorized),
      "doesn't return HTML for uncategorized by default"
    );
    assert.present(
      categoryBadgeHTML(uncategorized, { allowUncategorized: true }),
      "returns HTML"
    );
  });

  test("category names are wrapped in dir-spans", function (assert) {
    const siteSettings = getOwner(this).lookup("service:site-settings");
    siteSettings.support_mixed_text_direction = true;

    const store = getOwner(this).lookup("service:store");
    const rtlCategory = store.createRecord("category", {
      name: "תכנות עם Ruby",
      id: 123,
      description_text: "cool description",
      color: "ff0",
      text_color: "f00",
    });

    const ltrCategory = store.createRecord("category", {
      name: "Programming in Ruby",
      id: 234,
    });

    let tag = domFromString(categoryBadgeHTML(rtlCategory))[0];

    let dirSpan = tag.children[0].children[0];
    assert.strictEqual(dirSpan.dir, "auto");

    tag = domFromString(categoryBadgeHTML(ltrCategory))[0];
    dirSpan = tag.children[0].children[0];
    assert.strictEqual(dirSpan.dir, "auto");
  });

  test("category style types", function (assert) {
    const store = getOwner(this).lookup("service:store");
    const category = store.createRecord("category", { name: "hello", id: 123 });

    assert.true(
      categoryBadgeHTML(category).includes("--style-square"),
      "has square style by default"
    );

    assert.true(
      categoryBadgeHTML(category, {
        styleType: "icon",
        icon: "book",
      }).includes("--style-icon"),
      "has icon style"
    );

    assert.true(
      categoryBadgeHTML(category, {
        styleType: "emoji",
        emoji: "wave",
      }).includes("--style-emoji"),
      "has emoji style"
    );
  });

  test("emoji style falls back to square when emoji are disabled", function (assert) {
    const store = getOwner(this).lookup("service:store");
    const category = store.createRecord("category", {
      name: "hello",
      id: 123,
      style_type: "emoji",
      emoji: "wave",
    });
    helperContext().siteSettings.enable_emoji = false;

    const badge = categoryBadgeHTML(category);

    assert.true(badge.includes("--style-square"), "has square style");
    assert.false(badge.includes(":wave:"), "doesn't leak the emoji code");
  });

  test("category style with ancestors", function (assert) {
    const store = getOwner(this).lookup("service:store");

    const emojiParent = store.createRecord("category", {
      name: "hello",
      id: 123,
      style_type: "icon",
      icon: "book",
    });
    const emojiChild = store.createRecord("category", {
      name: "world",
      id: 456,
      style_type: "icon",
      icon: "file",
      parent_category_id: emojiParent.id,
    });

    const badge = categoryBadgeHTML(emojiChild, { ancestors: [emojiParent] });

    assert.true(badge.includes("d-icon-book"), "has parent with book icon");
    assert.true(badge.includes("d-icon-file"), "has child with file icon");
  });

  test("ancestors", function (assert) {
    const store = getOwner(this).lookup("service:store");
    let badge;

    const parent = store.createRecord("category", {
      name: "parent",
      id: 1,
    });
    const child = store.createRecord("category", {
      name: "child",
      id: 2,
      parent_category_id: parent.id,
    });

    badge = categoryBadgeHTML(child);
    assert.strictEqual((badge.match(/data-category-id/g) || []).length, 1);
    assert.false(badge.includes('data-category-id="1"'), "excludes parent");
    assert.true(badge.includes('data-category-id="2"'), "includes child");

    badge = categoryBadgeHTML(child, { ancestors: [parent] });
    assert.strictEqual((badge.match(/data-category-id/g) || []).length, 2);
    assert.true(badge.includes('data-category-id="1"'), "includes parent");
    assert.true(badge.includes('data-category-id="2"'), "includes child");
  });

  test("read-only badge appears only once with ancestors", function (assert) {
    const store = getOwner(this).lookup("service:store");

    const parent = store.createRecord("category", {
      name: "parent",
      id: 1,
    });
    const child = store.createRecord("category", {
      name: "child",
      id: 2,
      parent_category_id: parent.id,
    });

    const badge = categoryBadgeHTML(child, {
      ancestors: [parent],
      readOnly: true,
    });

    const readOnlyMatches = badge.match(/class="read-only"/g) || [];
    assert.strictEqual(
      readOnlyMatches.length,
      1,
      "read-only badge appears exactly once"
    );
    assert.true(
      badge.includes("read-only"),
      "read-only badge is present in the output"
    );
  });

  module("options", function (nestedHooks) {
    let category;

    nestedHooks.beforeEach(function () {
      category = getOwner(this)
        .lookup("service:store")
        .createRecord("category", {
          name: "hello",
          id: 123,
          slug: "hello",
          color: "ff0",
        });
    });

    function badge(opts) {
      return domFromString(categoryBadgeHTML(category, opts))[0];
    }

    test("links to the given url", function (assert) {
      assert.dom(badge({ url: "/gizmo" })).hasAttribute("href", "/gizmo");
      assert
        .dom(badge())
        .hasAttribute("href", "/c/hello/123", "links to the category");
    });

    test("renders a span without a link", function (assert) {
      const span = badge({ link: false });

      assert.strictEqual(span.tagName, "SPAN");
      assert.dom(span).doesNotHaveAttribute("href");
      assert.strictEqual(badge({ link: "false" }).tagName, "SPAN");
    });

    test("adds the extra classes to the wrapper", function (assert) {
      assert.dom(badge({ extraClasses: "gizmo" })).hasClass("gizmo");
    });

    test("sets the badge color with previewColor", function (assert) {
      assert
        .dom(".badge-category", badge({ previewColor: true }))
        .hasAttribute("style", "--category-badge-color: #ff0");
      assert
        .dom(".badge-category", badge())
        .doesNotHaveAttribute("style", "only with previewColor");
    });

    test("marks a restricted category", function (assert) {
      category.read_restricted = true;

      assert.dom(".badge-category", badge()).hasClass("restricted");
      assert.dom(".badge-category svg", badge()).exists();
    });

    test("shows the topic count", function (assert) {
      assert.dom(".topic-count", badge({ topicCount: 20 })).hasText("× 20");
    });

    test("shows the subcategories and read-only indicators", function (assert) {
      const wrapper = badge({ hasSubcategories: true, readOnly: true });

      assert.dom(".plus-subcategories", wrapper).exists();
      assert.dom(".read-only", wrapper).exists();
      assert.dom(".plus-subcategories", badge()).doesNotExist();
      assert.dom(".read-only", badge()).doesNotExist();
    });

    test("shows the topic count on the category only, not its ancestors", function (assert) {
      const parent = getOwner(this)
        .lookup("service:store")
        .createRecord("category", { name: "parent", id: 1 });

      const html = categoryBadgeHTML(category, {
        ancestors: [parent],
        topicCount: 20,
      });

      assert.strictEqual((html.match(/topic-count/g) || []).length, 1);
    });

    test("replaceCategoryLinkRenderer replaces the renderer", function (assert) {
      try {
        replaceCategoryLinkRenderer(
          (c, opts) => `${c.name}:${opts.extraClasses}`
        );

        assert.strictEqual(
          categoryBadgeHTML(category, { extraClasses: "gizmo" }),
          "hello:gizmo"
        );
      } finally {
        replaceCategoryLinkRenderer(defaultCategoryLinkRenderer);
      }
    });

    test("categoryLinkHTML passes on the supported options", function (assert) {
      const wrapper = domFromString(
        categoryLinkHTML(category, {
          link: false,
          extraClasses: "gizmo",
          previewColor: true,
          styleType: "icon",
          icon: "book",
          url: "/ignored",
        }).toString()
      )[0];

      assert.strictEqual(wrapper.tagName, "SPAN");
      assert.dom(wrapper).hasClass("gizmo");
      assert
        .dom(".badge-category", wrapper)
        .hasClass("--style-icon")
        .hasAttribute("style", "--category-badge-color: #ff0");
      assert.dom(".d-icon-book", wrapper).exists();
    });

    test("categoryLinkHTML reads the options from a hash", function (assert) {
      const wrapper = domFromString(
        categoryLinkHTML(category, {
          hash: { extraClasses: "gizmo" },
        }).toString()
      )[0];

      assert.dom(wrapper).hasClass("gizmo");
    });

    test("categoryLinkHTML passes on allowUncategorized and the emoji", function (assert) {
      helperContext().site.set("uncategorized_category_id", 123);

      assert.strictEqual(categoryLinkHTML(category).toString(), "");

      const wrapper = domFromString(
        categoryLinkHTML(category, {
          allowUncategorized: true,
          styleType: "emoji",
          emoji: "wave",
        }).toString()
      )[0];

      assert.dom(".emoji[title='wave']", wrapper).exists();
    });
  });
});
