import { settled } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { shellWindow } from "discourse/tests/helpers/panel-dock-window-shell";
import { mirrorOpener } from "discourse/ui-kit/panel-dock/-internals/opener-mirror";

/**
 * Oracle for the residue of mirroring.
 *
 * The server now serves the window its stylesheets, its colour scheme, its
 * icons and its root classes, so almost all of the cloning the opening page
 * used to do is gone. What cannot be served is what the *application* derives
 * at runtime from state no server rendering the shell could be told: the CSS it
 * generates from the categories and block outlets this page knows about, the
 * icons it has picked up since boot, whether it is being read on a narrow
 * screen, and which of the two colour schemes is currently live.
 *
 * Enumerated by selector on purpose. The general mirror this replaced could not
 * tell a stylesheet the server had already served from one it had not, and
 * cloned both.
 */
module("Integration | Component | panel dock opener mirror", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    this.frames = [];
    this.cleanups = [];
  });

  hooks.afterEach(function () {
    this.cleanups.forEach((fn) => fn());
    this.frames.forEach((frame) => frame.remove());
  });

  /** Adds a style the application would have generated, for one test only. */
  function styleSource(context, id, css) {
    const style = document.createElement("style");
    style.id = id;
    style.textContent = css;
    document.head.appendChild(style);
    context.cleanups.push(() => style.remove());
    return style;
  }

  function mirrored(doc, selector) {
    return doc.querySelector(selector);
  }

  /**
   * The page's sprite container, made if the loader has not made it yet.
   *
   * Never a second element carrying the same id: `getElementById` would return
   * whichever came first, so the outcome would depend on whether an earlier
   * test in the run happened to load a sprite.
   */
  function spriteContainer(context) {
    const existing = document.getElementById("svg-sprites");
    if (existing) {
      const before = existing.innerHTML;
      context.cleanups.push(() => (existing.innerHTML = before));
      return existing;
    }

    const created = document.createElement("div");
    created.id = "svg-sprites";
    document.body.appendChild(created);
    context.cleanups.push(() => created.remove());
    return created;
  }

  test("opener mirror copies the styles the application generates at runtime", async function (assert) {
    styleSource(this, "d-styles", ":root { --oracle: 1; }");
    styleSource(
      this,
      "d-styles-block-outlets",
      ".oracle-outlet { color: red; }"
    );

    const { doc } = shellWindow(this, "oracle-key");
    const mirror = mirrorOpener(doc);
    this.cleanups.push(() => mirror.dispose());
    await settled();

    assert.strictEqual(
      mirrored(doc, "#d-styles").textContent,
      ":root { --oracle: 1; }"
    );
    assert.strictEqual(
      mirrored(doc, "#d-styles-block-outlets").textContent,
      ".oracle-outlet { color: red; }"
    );
  });

  test("opener mirror follows generated styles as the page rewrites them", async function (assert) {
    const source = styleSource(this, "d-styles", ":root { --oracle: 1; }");

    const { doc } = shellWindow(this, "oracle-key");
    const mirror = mirrorOpener(doc);
    this.cleanups.push(() => mirror.dispose());
    await settled();

    // A `textContent` assignment replaces the text node rather than editing it,
    // which is why watching character data alone is not enough.
    source.textContent = ":root { --oracle: 2; }";
    await settled();

    assert.strictEqual(
      mirrored(doc, "#d-styles").textContent,
      ":root { --oracle: 2; }"
    );
  });

  test("opener mirror carries icons the page picked up after boot", async function (assert) {
    // Reuses the page's own container when the sprite loader has already made
    // one. Appending a second element with the same id would be shadowed by
    // the first, so the test would pass or fail on what ran before it.
    const sprites = spriteContainer(this);

    const { doc } = shellWindow(this, "oracle-key");
    const mirror = mirrorOpener(doc);
    this.cleanups.push(() => mirror.dispose());
    await settled();

    // The container exists from boot but is filled asynchronously, and grows
    // again whenever an icon outside the served bundle is first used. A
    // one-shot clone at adoption time would leave the window iconless.
    sprites.innerHTML = `<svg><symbol id="icon-oracle"></symbol></svg>`;
    await settled();

    assert
      .dom(".d-panel-dock-window__sprites #icon-oracle", doc)
      .exists("an icon added after the window opened still resolves in it");
  });

  test("opener mirror follows the live colour scheme", async function (assert) {
    // The runner page already serves both scheme links, and everything that
    // looks one up — `interface-color.js:145` included — takes the first match.
    // So this drives the real links rather than appending rivals behind them,
    // which is also what the reader's own toggle does.
    const light = document.querySelector("link.light-scheme");
    const dark = document.querySelector("link.dark-scheme");
    assert.notStrictEqual(light, null, "the page serves a light scheme");
    assert.notStrictEqual(dark, null, "the page serves a dark scheme");

    const restore = { light: light.media, dark: dark.media };
    this.cleanups.push(() => {
      light.media = restore.light;
      dark.media = restore.dark;
    });

    const { doc } = shellWindow(this, "oracle-key");
    const mirror = mirrorOpener(doc);
    this.cleanups.push(() => mirror.dispose());
    await settled();

    // The server resolves the scheme correctly when the window loads, but the
    // reader can toggle afterwards, and toggling is a `media` flip on these two
    // links rather than a navigation.
    light.media = "none";
    dark.media = "all";
    await settled();

    assert.dom("link.light-scheme", doc).hasAttribute("media", "none");
    assert.dom("link.dark-scheme", doc).hasAttribute("media", "all");
  });

  test("opener mirror follows the page's root classes", async function (assert) {
    const { doc } = shellWindow(this, "oracle-key");
    const mirror = mirrorOpener(doc);
    this.cleanups.push(() => mirror.dispose());
    await settled();

    document.documentElement.classList.add("oracle-mobile-view");
    this.cleanups.push(() =>
      document.documentElement.classList.remove("oracle-mobile-view")
    );
    await settled();

    // `mobile-view` and its siblings are written at runtime, never served, so
    // without this the window loses every responsive rule keyed off them.
    //
    // Read off the element rather than through `assert.dom`, which type-checks
    // an element argument with `instanceof` and so rejects one belonging to
    // another document's realm.
    assert.true(
      doc.documentElement.classList.contains("oracle-mobile-view"),
      "the window follows the page it belongs to"
    );
  });

  test("opener mirror leaves the window's own marker alone", async function (assert) {
    const { doc } = shellWindow(this, "oracle-key");
    const mirror = mirrorOpener(doc);
    this.cleanups.push(() => mirror.dispose());

    document.documentElement.classList.add("oracle-mobile-view");
    this.cleanups.push(() =>
      document.documentElement.classList.remove("oracle-mobile-view")
    );
    await settled();

    // The server owns `data-d-panel-dock`; mirroring the class list must not
    // touch it, because it is how the next page recognises this window.
    assert.strictEqual(doc.documentElement.dataset.dPanelDock, "oracle-key");
  });

  test("opener mirror tolerates a page that has none of these yet", async function (assert) {
    const { doc } = shellWindow(this, "oracle-key");

    const mirror = mirrorOpener(doc);
    this.cleanups.push(() => mirror.dispose());
    await settled();

    assert
      .dom(".d-panel-dock-window__mount", doc)
      .exists("the shell is intact");
  });

  test("opener mirror stops following the page once disposed", async function (assert) {
    const source = styleSource(this, "d-styles", ":root { --oracle: 1; }");

    const { doc } = shellWindow(this, "oracle-key");
    const mirror = mirrorOpener(doc);
    await settled();

    mirror.dispose();
    source.textContent = ":root { --oracle: 2; }";
    await settled();

    assert.strictEqual(
      mirrored(doc, "#d-styles").textContent,
      ":root { --oracle: 1; }",
      "a disposed mirror owns nothing in the window"
    );
  });
});
