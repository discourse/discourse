import EmberObject from "@ember/object";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import { defaultRenderTag, replaceTagRenderer } from "discourse/lib/render-tag";
import renderTags, {
  addTagsHtmlCallback,
  clearTagsHtmlCallbacks,
} from "discourse/lib/render-tags";
import { i18n } from "discourse-i18n";

module("Unit | Utility | render-tags", function (hooks) {
  setupTest(hooks);

  hooks.afterEach(() => clearTagsHtmlCallbacks());

  test("renderTags with tagClasses param", function (assert) {
    const topic = EmberObject.create({
      tags: ["cat", "dog"],
      get(prop) {
        return this[prop];
      },
    });

    const tagClasses = {
      cat: "meow",
      dog: "woof",
    };

    const classResult = renderTags(topic, { tagClasses });
    const classDiv = document.createElement("div");
    classDiv.innerHTML = classResult;

    const catTagLink = classDiv.querySelector('[data-tag-name="cat"]');
    const dogTagLink = classDiv.querySelector('[data-tag-name="dog"]');

    assert.notStrictEqual(catTagLink, null, "cat tag exists");
    assert.notStrictEqual(dogTagLink, null, "dog tag exists");

    assert.true(
      catTagLink.classList.contains("meow"),
      "adds the meow class to the cat tag"
    );
    assert.true(
      dogTagLink.classList.contains("woof"),
      "adds the woof class to the dog tag"
    );
  });

  test("callback returning an array renders each item as its own li", function (assert) {
    addTagsHtmlCallback(() => ["<a>one</a>", "<a>two</a>", "<a>three</a>"]);

    const topic = EmberObject.create({
      tags: [],
      get(prop) {
        return this[prop];
      },
    });

    const result = renderTags(topic, {});
    const div = document.createElement("div");
    div.innerHTML = result;

    const items = div.querySelectorAll(".discourse-tags > li");
    assert.strictEqual(items.length, 3, "each array item gets its own li");
    assert.strictEqual(items[0].querySelector("a").textContent, "one");
    assert.strictEqual(items[1].querySelector("a").textContent, "two");
    assert.strictEqual(items[2].querySelector("a").textContent, "three");
    assert.dom(".discourse-tags__tag-separator", items[0]).exists();
    assert.dom(".discourse-tags__tag-separator", items[1]).exists();
    assert.dom(".discourse-tags__tag-separator", items[2]).doesNotExist();
  });

  test("callback returning an array alongside regular tags", function (assert) {
    addTagsHtmlCallback(() => ["<a>one</a>", "<a>two</a>"]);

    const topic = EmberObject.create({
      tags: ["alpha", "beta"],
      get(prop) {
        return this[prop];
      },
    });

    const result = renderTags(topic, {});
    const div = document.createElement("div");
    div.innerHTML = result;

    const items = div.querySelectorAll(".discourse-tags > li");
    assert.strictEqual(items.length, 4, "tags and array items each own li");
    assert.dom('[data-tag-name="alpha"]', items[0]).exists();
    assert.dom('[data-tag-name="beta"]', items[1]).exists();
    assert.strictEqual(items[2].querySelector("a").textContent, "one");
    assert.strictEqual(items[3].querySelector("a").textContent, "two");
  });

  module("options", function (nestedHooks) {
    let rendered;

    nestedHooks.beforeEach(function () {
      rendered = [];
      replaceTagRenderer((tag, params) => {
        rendered.push({ tag, params });
        return `<a>${typeof tag === "string" ? tag : tag.name}</a>`;
      });
    });

    nestedHooks.afterEach(function () {
      replaceTagRenderer(defaultRenderTag);
    });

    function buildTopic(attrs) {
      return EmberObject.create({
        get(prop) {
          return this[prop];
        },
        ...attrs,
      });
    }

    test("renders nothing without tags or callbacks", function (assert) {
      assert.strictEqual(renderTags(buildTopic({ tags: [] }), {}), "");
      assert.strictEqual(renderTags(null, {}), "");
    });

    test("renders the tags in a labelled list with separators", function (assert) {
      const result = renderTags(buildTopic({ tags: ["cat", "dog"] }), {
        className: "gizmo",
      });

      assert.strictEqual(
        result,
        `<ul class='discourse-tags gizmo' aria-label=${i18n("tagging.tags")}>` +
          `<li><a>cat</a><span class="discourse-tags__tag-separator">,</span></li>` +
          `<li><a>dog</a></li></ul>`
      );
    });

    test("renders the given tags without a topic", function (assert) {
      renderTags(null, { tags: ["cat"] });

      assert.deepEqual(
        rendered.map(({ tag }) => tag),
        ["cat"]
      );
    });

    test("uses the visible list tags in list mode", function (assert) {
      renderTags(
        buildTopic({ tags: ["cat", "hidden"], visibleListTags: ["cat"] }),
        { mode: "list" }
      );

      assert.deepEqual(
        rendered.map(({ tag }) => tag),
        ["cat"]
      );
    });

    test("passes the topic's details and the options to the renderer", function (assert) {
      renderTags(
        buildTopic({
          tags: [{ name: "cat" }],
          isPrivateMessage: true,
          tags_descriptions: { cat: "Meow" },
        }),
        {
          tagsForUser: "gizmo",
          tagName: "span",
          size: "large",
          tagClasses: { cat: "meow" },
        }
      );

      const { params } = rendered[0];
      assert.strictEqual(params.description, "Meow");
      assert.true(params.isPrivateMessage);
      assert.strictEqual(params.tagsForUser, "gizmo");
      assert.strictEqual(params.tagName, "span");
      assert.strictEqual(params.size, "large");
      assert.strictEqual(params.extraClass, "meow");
    });

    test("orders callbacks by priority and drops empty results", function (assert) {
      addTagsHtmlCallback(() => "<b>low</b>", { priority: 1 });
      addTagsHtmlCallback(() => "", { priority: 5 });
      addTagsHtmlCallback(() => ["<b>high</b>", null], { priority: 10 });

      const div = document.createElement("div");
      div.innerHTML = renderTags(buildTopic({ tags: [] }), {});

      assert.deepEqual(
        [...div.querySelectorAll("li")].map((li) => li.textContent),
        ["high,", "low"]
      );
    });

    test("passes the topic and the options to callbacks", function (assert) {
      const topic = buildTopic({ tags: [] });
      const params = { size: "large" };
      let received;
      addTagsHtmlCallback((...args) => {
        received = args;
      });

      renderTags(topic, params);

      assert.strictEqual(received[0], topic);
      assert.strictEqual(received[1], params);
    });

    test("skips callbacks without a topic", function (assert) {
      let called = false;
      addTagsHtmlCallback(() => {
        called = true;
      });

      renderTags(null, { tags: ["cat"] });

      assert.false(called);
    });
  });
});
