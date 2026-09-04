import { settled } from "@ember/test-helpers";
import { module, test } from "qunit";
import sinon from "sinon";
import DiscourseURL from "discourse/lib/url";
import {
  skeletonKey,
  writeSkeleton,
} from "discourse/ui-kit/panel-dock/-internals/window-skeleton";

const SPRITE_CONTAINER_ID = "svg-sprites";
const NOTE_CONTAINER =
  "main.d-panel-dock-window__reconnecting > .empty-state__container";

/**
 * Oracle for the panel window's static shell. The window runs no script, so
 * every assertion here is about what the opening page writes and keeps
 * writing into a document it does not live in.
 */
module(
  "Integration | Component | panel dock window skeleton",
  function (hooks) {
    hooks.beforeEach(function () {
      this.cleanups = [];
      this.frames = [];
    });

    hooks.afterEach(function () {
      this.cleanups.reverse().forEach((undo) => undo());
      this.frames.forEach((frame) => frame.remove());
    });

    /** A blank same-origin document standing in for a panel window. */
    function blankWindow(context) {
      const frame = document.createElement("iframe");
      frame.setAttribute("aria-hidden", "true");
      frame.style.width = "1px";
      frame.style.height = "1px";
      document.body.appendChild(frame);
      context.frames.push(frame);
      return frame.contentDocument;
    }

    function addToPage(context, parent, node) {
      parent.appendChild(node);
      context.cleanups.push(() => node.remove());
      return node;
    }

    /** Lets the mirrors observing the opening page catch up. */
    async function flushMirrors() {
      await settled();
      await new Promise((resolve) => setTimeout(resolve, 0));
    }

    function indexOf(parent, selector) {
      return Array.from(parent.children).findIndex((child) =>
        child.matches(selector)
      );
    }

    test("window skeleton stamps the panel's key on the document", function (assert) {
      const doc = blankWindow(this);

      writeSkeleton(doc, "oracle-key", "Oracle panel");

      assert.strictEqual(
        doc.documentElement.dataset.dPanelDock,
        "oracle-key",
        "the key is readable from the document element"
      );
      assert.strictEqual(
        skeletonKey(doc),
        "oracle-key",
        "the key round-trips through the reader"
      );
      assert.strictEqual(
        doc.title,
        "Oracle panel",
        "the window carries the panel's title"
      );
      assert.strictEqual(
        skeletonKey(blankWindow(this)),
        undefined,
        "a window that was never prepared reports no key"
      );
    });

    test("window skeleton builds the mount and the float outlets in one wrapper", function (assert) {
      const doc = blankWindow(this);

      const skeleton = writeSkeleton(doc, "oracle-key", "Oracle panel");

      assert.strictEqual(
        doc.querySelectorAll(".d-panel-dock-window").length,
        1,
        "one wrapper holds the whole shell"
      );

      const wrapper = doc.querySelector(".d-panel-dock-window");
      assert.strictEqual(
        indexOf(wrapper, ".d-panel-dock-window__mount"),
        0,
        "the mount comes first"
      );
      assert.strictEqual(
        indexOf(wrapper, "#d-menu-portals"),
        1,
        "the menu outlet follows the mount"
      );
      assert.strictEqual(
        indexOf(wrapper, "#d-tooltip-portals"),
        2,
        "the tooltip outlet follows the menu outlet"
      );
      assert.strictEqual(
        indexOf(wrapper, ".d-panel-dock-window__sprites"),
        3,
        "the sprite store comes last"
      );

      assert
        .dom("#d-menu-portals", doc)
        .hasClass("d-panel-dock-window__portals");
      assert
        .dom("#d-tooltip-portals", doc)
        .hasClass("d-panel-dock-window__portals");
      assert
        .dom(".d-panel-dock-window__sprites", doc)
        .hasAttribute("hidden", "", "the sprite store never paints");

      assert.strictEqual(
        skeleton.mount,
        doc.querySelector(".d-panel-dock-window__mount"),
        "the returned mount is the element in the window"
      );
      assert.strictEqual(
        skeleton.mount.ownerDocument,
        doc,
        "the mount belongs to the window's document"
      );
    });

    test("window skeleton creates the window's nodes in the opening page's realm", function (assert) {
      const doc = blankWindow(this);

      const skeleton = writeSkeleton(doc, "oracle-key", "Oracle panel");

      assert.true(
        skeleton.mount instanceof HTMLElement,
        "the mount answers to the opening page's HTMLElement"
      );
      assert.true(
        doc.getElementById("d-menu-portals") instanceof HTMLElement,
        "the menu outlet answers to the opening page's HTMLElement"
      );
      assert.false(
        doc.body instanceof HTMLElement,
        "the window's own body does not, which is what makes the check meaningful"
      );
    });

    test("window skeleton mirrors the opening page's root attributes", async function (assert) {
      document.documentElement.classList.add("oracle-root-class");
      document.body.classList.add("oracle-body-class");
      this.cleanups.push(() => {
        document.documentElement.classList.remove("oracle-root-class");
        document.body.classList.remove("oracle-body-class");
      });

      const doc = blankWindow(this);
      const skeleton = writeSkeleton(doc, "oracle-key", "Oracle panel");

      assert.true(
        doc.documentElement.classList.contains("oracle-root-class"),
        "the page's root classes apply"
      );
      assert.strictEqual(
        doc.documentElement.lang,
        document.documentElement.lang,
        "the page's language applies"
      );
      assert.true(
        doc.body.classList.contains("oracle-body-class"),
        "the page's body classes apply"
      );

      document.documentElement.classList.add("oracle-dark-mode");
      document.body.classList.add("oracle-late-body-class");
      this.cleanups.push(() => {
        document.documentElement.classList.remove("oracle-dark-mode");
        document.body.classList.remove("oracle-late-body-class");
      });
      await flushMirrors();

      assert.true(
        doc.documentElement.classList.contains("oracle-dark-mode"),
        "a later root class change follows"
      );
      assert.true(
        doc.body.classList.contains("oracle-late-body-class"),
        "a later body class change follows"
      );
      assert.true(
        skeleton.mount.isConnected,
        "mirroring the body never discards the shell"
      );
      assert.strictEqual(
        doc.querySelectorAll(".d-panel-dock-window").length,
        1,
        "mirroring the body never duplicates the shell"
      );

      document.documentElement.classList.remove("oracle-dark-mode");
      await flushMirrors();

      assert.false(
        doc.documentElement.classList.contains("oracle-dark-mode"),
        "a removed root class follows too"
      );
    });

    test("window skeleton clones stylesheets from the page's body as well as its head", function (assert) {
      const headLink = document.createElement("link");
      headLink.rel = "stylesheet";
      headLink.href = "/oracle-head.css";
      addToPage(this, document.head, headLink);

      const bodyLink = document.createElement("link");
      bodyLink.rel = "stylesheet";
      bodyLink.href = "/oracle-body.css";
      addToPage(this, document.body, bodyLink);

      const inlineStyle = document.createElement("style");
      inlineStyle.textContent = ".oracle-inline { color: rebeccapurple; }";
      addToPage(this, document.body, inlineStyle);

      const doc = blankWindow(this);
      writeSkeleton(doc, "oracle-key", "Oracle panel");

      const headClone = indexOf(doc.head, "link[href$='/oracle-head.css']");
      const bodyClone = indexOf(doc.head, "link[href$='/oracle-body.css']");
      const styleClones = Array.from(doc.head.querySelectorAll("style")).filter(
        (node) => node.textContent.includes("rebeccapurple")
      );

      assert.notStrictEqual(
        headClone,
        -1,
        "a stylesheet in the head is cloned"
      );
      assert.notStrictEqual(
        bodyClone,
        -1,
        "a stylesheet in the body is cloned, which is where they really live"
      );
      assert.strictEqual(
        styleClones.length,
        1,
        "an inline style rendered by the app is cloned once"
      );
      assert.true(
        headClone < bodyClone,
        "the clones keep the page's own order, so later rules still win"
      );
      assert.true(
        bodyClone < Array.from(doc.head.children).indexOf(styleClones[0]),
        "the inline style stays after the stylesheets it overrides"
      );
    });

    test("window skeleton clones a stylesheet link with an absolute href", function (assert) {
      const bodyLink = document.createElement("link");
      bodyLink.rel = "stylesheet";
      bodyLink.href = "/oracle-body.css";
      addToPage(this, document.body, bodyLink);

      const doc = blankWindow(this);
      writeSkeleton(doc, "oracle-key", "Oracle panel");

      const clone = doc.head.querySelector("link[href$='/oracle-body.css']");
      assert.strictEqual(
        clone.getAttribute("href"),
        new URL("/oracle-body.css", document.location.href).href,
        "a relative href would resolve against the blank window and load nothing"
      );
    });

    test("window skeleton puts the color meta tags before the cloned stylesheets", function (assert) {
      const colorScheme = document.createElement("meta");
      colorScheme.name = "color-scheme";
      colorScheme.content = "oracle-light oracle-dark";
      colorScheme.dataset.oracleProbe = "color-scheme";
      addToPage(this, document.head, colorScheme);

      const themeColor = document.createElement("meta");
      themeColor.name = "theme-color";
      themeColor.content = "#abcdef";
      themeColor.dataset.oracleProbe = "theme-color";
      addToPage(this, document.head, themeColor);

      const bodyLink = document.createElement("link");
      bodyLink.rel = "stylesheet";
      bodyLink.href = "/oracle-body.css";
      addToPage(this, document.body, bodyLink);

      const doc = blankWindow(this);
      writeSkeleton(doc, "oracle-key", "Oracle panel");

      const children = Array.from(doc.head.children);
      const lastMeta = children.reduce(
        (last, child, index) =>
          child.matches("meta[name='color-scheme'], meta[name='theme-color']")
            ? index
            : last,
        -1
      );
      const firstSheet = children.findIndex((child) =>
        child.matches("link[rel='stylesheet'], style")
      );

      assert
        .dom("meta[data-oracle-probe='color-scheme']", doc.head)
        .hasAttribute("content", "oracle-light oracle-dark");
      assert
        .dom("meta[data-oracle-probe='theme-color']", doc.head)
        .hasAttribute("content", "#abcdef");
      assert.notStrictEqual(lastMeta, -1, "the color metas are cloned");
      assert.true(
        lastMeta < firstSheet,
        "the document's background is settled before any stylesheet can paint it"
      );
    });

    test("window skeleton mirrors a stylesheet the page adds after the window opened", async function (assert) {
      const doc = blankWindow(this);
      writeSkeleton(doc, "oracle-key", "Oracle panel");

      assert
        .dom("link[href$='/oracle-late.css']", doc.head)
        .doesNotExist("nothing is cloned before the page adds it");

      const lateLink = document.createElement("link");
      lateLink.rel = "stylesheet";
      lateLink.href = "/oracle-late.css";
      addToPage(this, document.body, lateLink);
      await flushMirrors();

      assert
        .dom("link[href$='/oracle-late.css']", doc.head)
        .exists("a stylesheet loaded later reaches the window");

      lateLink.remove();
      await flushMirrors();

      assert
        .dom("link[href$='/oracle-late.css']", doc.head)
        .doesNotExist("and a stylesheet the page drops is dropped here too");
    });

    test("window skeleton leaves the window alone while the page merely renders", async function (assert) {
      const bodyLink = document.createElement("link");
      bodyLink.rel = "stylesheet";
      bodyLink.href = "/oracle-body.css";
      addToPage(this, document.body, bodyLink);

      const inlineStyle = document.createElement("style");
      inlineStyle.textContent = ".oracle-inline { color: rebeccapurple; }";
      addToPage(this, document.body, inlineStyle);

      const doc = blankWindow(this);
      writeSkeleton(doc, "oracle-key", "Oracle panel");
      await flushMirrors();

      const records = [];
      const watcher = new MutationObserver((mutations) =>
        records.push(...mutations)
      );
      watcher.observe(doc.head, { childList: true, subtree: true });
      this.cleanups.push(() => watcher.disconnect());

      const churn = document.createElement("div");
      churn.textContent = "an ordinary render";
      addToPage(this, document.body, churn);
      churn.appendChild(document.createElement("span"));
      await flushMirrors();

      assert.strictEqual(
        records.length,
        0,
        "the page re-renders constantly, so unrelated churn must not touch the window's head"
      );
    });

    test("window skeleton mirrors a stylesheet added inside a wrapper element", async function (assert) {
      const doc = blankWindow(this);
      writeSkeleton(doc, "oracle-key", "Oracle panel");

      const wrapper = document.createElement("div");
      const wrapped = document.createElement("link");
      wrapped.rel = "stylesheet";
      wrapped.href = "/oracle-wrapped.css";
      wrapper.appendChild(wrapped);
      addToPage(this, document.body, wrapper);
      await flushMirrors();

      assert
        .dom("link[href$='/oracle-wrapped.css']", doc.head)
        .exists(
          "stylesheets arrive inside a wrapper, so the added node is never the stylesheet itself"
        );

      wrapper.remove();
      await flushMirrors();

      assert
        .dom("link[href$='/oracle-wrapped.css']", doc.head)
        .doesNotExist("and removing the wrapper takes the clone with it");
    });

    test("window skeleton follows a color meta change on the page", async function (assert) {
      const themeColor = document.createElement("meta");
      themeColor.name = "theme-color";
      themeColor.content = "#abcdef";
      themeColor.dataset.oracleProbe = "theme-color";
      addToPage(this, document.head, themeColor);

      const doc = blankWindow(this);
      writeSkeleton(doc, "oracle-key", "Oracle panel");

      themeColor.content = "#123456";
      await flushMirrors();

      assert
        .dom("meta[data-oracle-probe='theme-color']", doc.head)
        .hasAttribute(
          "content",
          "#123456",
          "the document's theme color follows the page's"
        );
    });

    test("window skeleton follows a media change on a mirrored stylesheet", async function (assert) {
      const bodyLink = document.createElement("link");
      bodyLink.rel = "stylesheet";
      bodyLink.href = "/oracle-body.css";
      bodyLink.media = "all";
      addToPage(this, document.body, bodyLink);

      const doc = blankWindow(this);
      writeSkeleton(doc, "oracle-key", "Oracle panel");

      bodyLink.media = "none";
      await flushMirrors();

      assert
        .dom("link[href$='/oracle-body.css']", doc.head)
        .hasAttribute(
          "media",
          "none",
          "switching color mode disables a sheet by media, not by removing it"
        );

      bodyLink.media = "all";
      await flushMirrors();

      assert
        .dom("link[href$='/oracle-body.css']", doc.head)
        .hasAttribute("media", "all", "and switching back re-enables it");
    });

    test("window skeleton follows a text change in a mirrored inline style", async function (assert) {
      const inlineStyle = document.createElement("style");
      inlineStyle.textContent = ".oracle-inline { color: rebeccapurple; }";
      addToPage(this, document.body, inlineStyle);

      const doc = blankWindow(this);
      writeSkeleton(doc, "oracle-key", "Oracle panel");

      inlineStyle.textContent = ".oracle-inline { color: papayawhip; }";
      await flushMirrors();

      const clones = Array.from(doc.head.querySelectorAll("style")).filter(
        (node) => node.textContent.includes("papayawhip")
      );
      assert.strictEqual(
        clones.length,
        1,
        "replacing a style's text replaces its text node, so the mirror must watch children too"
      );
    });

    test("window skeleton clones icon sprites the page loads after the window opened", async function (assert) {
      let host = document.querySelector("discourse-assets-icons");
      if (!host) {
        host = addToPage(
          this,
          document.body,
          document.createElement("discourse-assets-icons")
        );
      }

      let container = document.getElementById(SPRITE_CONTAINER_ID);
      if (!container) {
        container = document.createElement("div");
        container.id = SPRITE_CONTAINER_ID;
        addToPage(this, host, container);
      }

      const doc = blankWindow(this);
      writeSkeleton(doc, "oracle-key", "Oracle panel");

      assert
        .dom("#oracle-symbol", doc)
        .doesNotExist("the sprite the page has not loaded yet is not there");

      const sprite = document.createElementNS(
        "http://www.w3.org/2000/svg",
        "svg"
      );
      sprite.innerHTML =
        '<symbol id="oracle-symbol"><path d="M0 0" /></symbol>';
      addToPage(this, container, sprite);
      await flushMirrors();

      assert
        .dom(".d-panel-dock-window__sprites #oracle-symbol", doc)
        .exists(
          "sprites arrive after boot, so a one-time clone would leave every icon blank"
        );

      const extra = document.createElementNS(
        "http://www.w3.org/2000/svg",
        "svg"
      );
      extra.innerHTML = '<symbol id="oracle-extra-symbol"></symbol>';
      addToPage(this, container, extra);
      await flushMirrors();

      assert
        .dom(".d-panel-dock-window__sprites #oracle-extra-symbol", doc)
        .exists("and a sprite loaded on demand reaches the window too");
    });

    test("window skeleton shows a note in place of the panel without discarding the mount", function (assert) {
      const doc = blankWindow(this);
      const skeleton = writeSkeleton(doc, "oracle-key", "Oracle panel");
      const mount = skeleton.mount;

      skeleton.setNote({
        title: "This panel lost the page it belongs to",
        body: "Reload that page to reconnect it, or close this window.",
      });

      assert.dom(".d-panel-dock-window", doc).hasClass("is-reconnecting");

      assert
        .dom("main.d-panel-dock-window__reconnecting", doc)
        .exists("the note is a landmark of its own");
      assert
        .dom(NOTE_CONTAINER, doc)
        .hasClass("--text-only")
        .hasClass("--panel-dock-reconnecting");
      assert
        .dom(NOTE_CONTAINER + " > .empty-state > h1.empty-state__title", doc)
        .hasText("This panel lost the page it belongs to");
      assert
        .dom(
          NOTE_CONTAINER +
            " > .empty-state > .empty-state__body > p[role='status']",
          doc
        )
        .hasText("Reload that page to reconnect it, or close this window.");

      assert
        .dom(".d-panel-dock-window__mount", doc)
        .hasAttribute(
          "hidden",
          "",
          "a document may carry only one main that is not hidden"
        );
      assert
        .dom("main:not([hidden])", doc)
        .exists({ count: 1 }, "so exactly one of them is exposed at a time");

      assert.strictEqual(
        skeleton.mount,
        mount,
        "the mount is the same element, so a tree rendered into it survives"
      );
      assert.true(mount.isConnected, "and it is still in the window");
    });

    test("window skeleton clears the note and leaves the mount in place", function (assert) {
      const doc = blankWindow(this);
      const skeleton = writeSkeleton(doc, "oracle-key", "Oracle panel");
      const mount = skeleton.mount;

      skeleton.setNote({ title: "Gone", body: "Reload." });
      skeleton.setNote({ title: "Still gone", body: "Really, reload." });

      assert.strictEqual(
        doc.querySelectorAll("main.d-panel-dock-window__reconnecting").length,
        1,
        "a second note replaces the first rather than stacking"
      );
      assert
        .dom("main.d-panel-dock-window__reconnecting .empty-state__title", doc)
        .hasText("Still gone");

      skeleton.setNote(null);

      assert
        .dom("main.d-panel-dock-window__reconnecting", doc)
        .doesNotExist("clearing the note removes it");
      assert
        .dom(".d-panel-dock-window", doc)
        .doesNotHaveClass("is-reconnecting");
      assert.strictEqual(skeleton.mount, mount, "the mount never moved");
      assert.true(mount.isConnected, "and is still in the window");
    });

    test("window skeleton routes a link clicked in the window through the opening page", function (assert) {
      const routeTo = sinon.stub(DiscourseURL, "routeTo");
      const doc = blankWindow(this);
      const skeleton = writeSkeleton(doc, "oracle-key", "Oracle panel");

      let prevented = null;
      const guard = (event) => {
        prevented = event.defaultPrevented;
        event.preventDefault();
      };
      doc.addEventListener("click", guard);
      this.cleanups.push(() => doc.removeEventListener("click", guard));

      const link = doc.createElement("a");
      link.href = "/t/oracle-topic/1";
      link.textContent = "Oracle topic";
      skeleton.mount.appendChild(link);

      link.dispatchEvent(
        new doc.defaultView.MouseEvent("click", {
          bubbles: true,
          cancelable: true,
          button: 0,
        })
      );

      assert.true(
        prevented,
        "the window has no router, so the click must not navigate it"
      );
      assert.true(
        routeTo.calledWith("/t/oracle-topic/1"),
        "the opening page routes instead"
      );
    });

    test("window skeleton stops mirroring the page once disposed", async function (assert) {
      const routeTo = sinon.stub(DiscourseURL, "routeTo");
      const doc = blankWindow(this);
      const skeleton = writeSkeleton(doc, "oracle-key", "Oracle panel");

      const guard = (event) => event.preventDefault();
      doc.addEventListener("click", guard);
      this.cleanups.push(() => doc.removeEventListener("click", guard));

      const link = doc.createElement("a");
      link.href = "/t/oracle-topic/1";
      skeleton.mount.appendChild(link);

      skeleton.dispose();
      skeleton.dispose();

      const lateLink = document.createElement("link");
      lateLink.rel = "stylesheet";
      lateLink.href = "/oracle-after-dispose.css";
      addToPage(this, document.body, lateLink);

      document.documentElement.classList.add("oracle-after-dispose");
      this.cleanups.push(() =>
        document.documentElement.classList.remove("oracle-after-dispose")
      );
      await flushMirrors();

      assert
        .dom("link[href$='/oracle-after-dispose.css']", doc.head)
        .doesNotExist("a disposed skeleton stops cloning stylesheets");
      assert.false(
        doc.documentElement.classList.contains("oracle-after-dispose"),
        "and stops mirroring root attributes"
      );

      link.dispatchEvent(
        new doc.defaultView.MouseEvent("click", {
          bubbles: true,
          cancelable: true,
          button: 0,
        })
      );

      assert.false(
        routeTo.called,
        "and stops routing clicks through a page it no longer belongs to"
      );
    });

    test("window skeleton hides the window until its stylesheets have settled", async function (assert) {
      const bodyLink = document.createElement("link");
      bodyLink.rel = "stylesheet";
      bodyLink.href = "/oracle-body.css";
      addToPage(this, document.body, bodyLink);

      const doc = blankWindow(this);
      const skeleton = writeSkeleton(doc, "oracle-key", "Oracle panel");
      this.cleanups.push(() => skeleton.dispose());

      assert.strictEqual(
        doc.documentElement.style.visibility,
        "hidden",
        "an unstyled flash is hidden rather than painted in the wrong colors"
      );

      const deadline = Date.now() + 3000;
      while (
        doc.documentElement.style.visibility === "hidden" &&
        Date.now() < deadline
      ) {
        await new Promise((resolve) => setTimeout(resolve, 50));
      }

      assert.notStrictEqual(
        doc.documentElement.style.visibility,
        "hidden",
        "and revealed once the stylesheets have loaded or failed"
      );
    });

    test("window skeleton replaces a previous shell when the window is adopted again", function (assert) {
      const doc = blankWindow(this);
      const first = writeSkeleton(doc, "oracle-key", "Oracle panel");
      first.dispose();

      const second = writeSkeleton(doc, "oracle-key", "Oracle panel");

      assert.strictEqual(
        doc.querySelectorAll(".d-panel-dock-window").length,
        1,
        "the shell left behind by the previous page is replaced, not joined"
      );
      assert.true(second.mount.isConnected, "the new mount is the live one");
      assert.false(
        first.mount.isConnected,
        "and the orphaned one is gone with it"
      );
    });
  }
);
