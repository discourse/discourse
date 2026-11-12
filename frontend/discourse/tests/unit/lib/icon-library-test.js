import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import {
  convertIconClass,
  iconElement,
  iconHTML,
  isExistingIconId,
  registerIconRenderer,
  renderIcon,
  replaceIcon,
  REPLACEMENTS,
  setIconList,
  SVG_NAMESPACE,
} from "discourse/lib/icon-library";

module("Unit | Utility | icon-library", function (hooks) {
  setupTest(hooks);

  test("creates icon element", function (assert) {
    const icon = iconElement("bars");
    assert.strictEqual(icon.tagName, "svg");
    assert.strictEqual(
      icon.className.baseVal,
      "fa d-icon d-icon-bars svg-icon fa-width-auto svg-node"
    );
  });

  test("convert icon names", function (assert) {
    const faIcon = convertIconClass("fab fa-facebook");
    assert.true(iconHTML(faIcon).includes("fab-facebook"), "FA syntax");

    const iconC = convertIconClass("  fab fa-facebook  ");
    assert.false(iconHTML(iconC).includes("  "), "trims whitespace");
  });

  test("uses replacement id for class when icon id contains dots", function (assert) {
    let html = iconHTML("user_menu.replies");
    assert.true(html.includes("d-icon-reply"), "uses replacement id for class");
    assert.false(
      html.includes("d-icon-user_menu.replies"),
      "does not use dotted id for class"
    );

    html = iconHTML("notification.replied");
    assert.true(
      html.includes("d-icon-reply"),
      "uses replacement id for notification icons"
    );
  });

  test("escape icon names, classes, titles and aria-label", function (assert) {
    let html = iconHTML("'<img src='x'>", {
      translatedTitle: "'<script src='y'>",
      label: "<iframe src='z'>",
      class: "'<link href='w'>",
      "aria-label": "<script>alert(1)",
    });
    assert.true(html.includes("&#x27;&lt;img src=&#x27;x&#x27;&gt;"));
    assert.true(html.includes("&#x27;&lt;script src=&#x27;y&#x27;&gt;"));
    assert.true(html.includes("&lt;iframe src=&#x27;z&#x27;&gt;"));
    assert.true(html.includes("&#x27;&lt;link href=&#x27;w&#x27;&gt;"));

    html = iconHTML("'<img src='x'>", {
      "aria-label": "<script>alert(1)",
    });
    assert.true(html.includes("aria-label='&lt;script&gt;alert(1)'"));
  });

  test("iconHTML renders the label, title and extra class", function (assert) {
    const html = iconHTML("bars", {
      class: "gadget",
      label: "Menu",
      title: "cancel",
      "aria-label": "Open menu",
    });

    assert.strictEqual(
      html,
      `<span class="svg-icon-title" title="Cancel"><svg class='fa d-icon d-icon-bars svg-icon fa-width-auto gadget svg-string' width='1em' height='1em' aria-hidden='false' aria-label='Open menu' xmlns="${SVG_NAMESPACE}"><use href="#bars" /></svg><span class="sr-only">Menu</span></span>`
    );
  });

  test("iconElement wraps the icon in a title span", function (assert) {
    const icon = iconElement("bars", { title: "Menu" });

    assert.strictEqual(icon.tagName, "SPAN");
    assert.strictEqual(icon.getAttribute("title"), "Menu");
    assert.strictEqual(icon.firstChild.namespaceURI, SVG_NAMESPACE);
    assert.strictEqual(icon.firstChild.getAttribute("aria-hidden"), "true");
    assert.strictEqual(icon.querySelector("use").getAttribute("href"), "#bars");
  });

  test("replaceIcon renders the destination icon", function (assert) {
    try {
      replaceIcon("gadget-source", "heart");

      assert.true(iconHTML("gadget-source").includes('href="#heart"'));
      assert.true(
        iconHTML("gadget-source").includes("d-icon-gadget-source"),
        "keeps the source id for the class"
      );
    } finally {
      delete REPLACEMENTS["gadget-source"];
    }
  });

  test("renderIcon picks the renderer for the render type", function (assert) {
    assert.strictEqual(renderIcon("string", "bars"), iconHTML("bars"));
    assert.strictEqual(
      renderIcon("gadget-type", "bars"),
      undefined,
      "nothing when no renderer handles the type"
    );
  });

  test("registerIconRenderer runs before the earlier renderers", function (assert) {
    registerIconRenderer({
      name: "gizmo",
      string(icon, params) {
        if (icon.id === "gizmo-icon") {
          return `gizmo:${icon.replacementId}:${params.class}`;
        }
      },
    });

    assert.strictEqual(
      iconHTML("gizmo-icon", { class: "big" }),
      "gizmo:undefined:big"
    );
    assert.true(
      iconHTML("bars").includes('href="#bars"'),
      "falls through when the renderer returns nothing"
    );
  });

  test("isExistingIconId checks the icon list", function (assert) {
    try {
      setIconList(["bars", "heart"]);

      assert.true(isExistingIconId("bars"));
      assert.false(isExistingIconId("gizmo-icon"));
    } finally {
      setIconList([]);
    }
  });
});
