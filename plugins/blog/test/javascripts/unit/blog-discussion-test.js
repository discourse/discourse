import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import EmbedMode from "discourse/lib/embed-mode";
import initializer from "discourse/plugins/blog/discourse/initializers/blog-discussion";

const BLOG_ORIGIN = "https://blog.example.com";
const PALETTE = { accent: "#d64b2a", paper: "#f5f0e6", ink: "#19382d" };

module("Unit | Initializer | blog-discussion", function (hooks) {
  setupTest(hooks);

  hooks.beforeEach(function () {
    this.originalEmbedMode = EmbedMode.enabled;
    this.root = document.documentElement;
    this.originalStyle = this.root.getAttribute("style");
    this.hadClass = this.root.classList.contains("discourse-blog-discussion");
    this.settings = this.owner.lookup("service:site-settings");
    this.settings.blog_enabled = true;
    this.settings.blog_url = BLOG_ORIGIN;
    for (const color of ["accent", "paper", "ink"]) {
      this.root.style.removeProperty(`--blog-${color}-color`);
    }
  });

  hooks.afterEach(function () {
    EmbedMode.enabled = this.originalEmbedMode;
    this.root.classList.toggle("discourse-blog-discussion", this.hadClass);
    if (this.originalStyle === null) {
      this.root.removeAttribute("style");
    } else {
      this.root.setAttribute("style", this.originalStyle);
    }
  });

  function sendPalette({ origin = BLOG_ORIGIN, ...palette } = {}) {
    window.dispatchEvent(
      new MessageEvent("message", {
        origin,
        data: { type: "discourse-blog-palette", ...PALETTE, ...palette },
      })
    );
  }

  test("applies the palette the blog sends with the embedded conversation", function (assert) {
    EmbedMode.enabled = true;
    this.root.classList.add("discourse-blog-discussion");
    initializer.initialize(this.owner);

    sendPalette();

    for (const color of ["accent", "paper", "ink"]) {
      assert.strictEqual(
        this.root.style.getPropertyValue(`--blog-${color}-color`),
        PALETTE[color],
        `the blog ${color} color styles the conversation`
      );
    }
  });

  test("ignores a palette from another origin", function (assert) {
    EmbedMode.enabled = true;
    this.root.classList.add("discourse-blog-discussion");
    initializer.initialize(this.owner);

    sendPalette({ origin: "https://example.com", paper: "#000000" });

    assert.strictEqual(
      this.root.style.getPropertyValue("--blog-paper-color"),
      "",
      "only the configured blog may restyle the conversation"
    );
  });

  test("ignores palette values that are not colors", function (assert) {
    EmbedMode.enabled = true;
    this.root.classList.add("discourse-blog-discussion");
    initializer.initialize(this.owner);

    sendPalette({ paper: "url(https://example.com/pixel)" });

    assert.strictEqual(
      this.root.style.getPropertyValue("--blog-paper-color"),
      "",
      "unexpected values never reach the stylesheet"
    );
    assert.strictEqual(
      this.root.style.getPropertyValue("--blog-accent-color"),
      "",
      "a partly invalid palette is refused whole"
    );
  });

  test("restores styling after an iframe-only reload loses the server class", function (assert) {
    EmbedMode.enabled = true;
    this.root.classList.remove("discourse-blog-discussion");
    const previousURL = window.location.href;
    try {
      window.history.replaceState(
        null,
        "",
        "?class_name=discourse-blog-discussion"
      );
      initializer.initialize(this.owner);
      assert.true(
        this.root.classList.contains("discourse-blog-discussion"),
        "the layout scope is restored from the embed URL"
      );

      sendPalette();
      assert.strictEqual(
        this.root.style.getPropertyValue("--blog-paper-color"),
        PALETTE.paper,
        "the blog palette still arrives"
      );
    } finally {
      window.history.replaceState(null, "", previousURL);
    }
  });

  test("leaves ordinary forum pages unchanged", function (assert) {
    EmbedMode.enabled = false;
    this.root.classList.add("discourse-blog-discussion");
    initializer.initialize(this.owner);
    sendPalette();
    assert.strictEqual(
      this.root.style.getPropertyValue("--blog-paper-color"),
      "",
      "a class alone cannot activate the palette"
    );
  });

  test("leaves other embeds unchanged", function (assert) {
    EmbedMode.enabled = true;
    this.root.classList.remove("discourse-blog-discussion");
    initializer.initialize(this.owner);
    sendPalette();
    assert.strictEqual(
      this.root.style.getPropertyValue("--blog-paper-color"),
      "",
      "other embedding sites retain the forum palette"
    );
  });

  test("does not apply the palette when the blog is disabled", function (assert) {
    EmbedMode.enabled = true;
    this.root.classList.add("discourse-blog-discussion");
    this.settings.blog_enabled = false;
    initializer.initialize(this.owner);
    sendPalette();
    assert.strictEqual(
      this.root.style.getPropertyValue("--blog-paper-color"),
      "",
      "disabled blogs do not initialize the palette"
    );
  });

  test("ignores palette messages without a usable blog URL", function (assert) {
    EmbedMode.enabled = true;
    this.root.classList.add("discourse-blog-discussion");
    this.settings.blog_url = "";
    initializer.initialize(this.owner);
    sendPalette();
    assert.strictEqual(
      this.root.style.getPropertyValue("--blog-paper-color"),
      "",
      "without a configured blog there is no origin to trust"
    );
  });
});
