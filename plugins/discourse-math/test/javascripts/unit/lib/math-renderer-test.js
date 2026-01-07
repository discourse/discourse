import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import {
  buildDiscourseMathOptions,
  renderKatex,
} from "discourse/plugins/discourse-math/lib/math-renderer";

module("Unit | Lib | math-renderer", function (hooks) {
  setupTest(hooks);

  module("renderKatex", function (nestedHooks) {
    nestedHooks.beforeEach(function () {
      this.container = document.createElement("div");
      document.body.appendChild(this.container);

      this.originalKatex = window.katex;
      window.katex = {
        render: (text, elem) => {
          if (text === "invalid\\syntax\\that\\fails") {
            throw new Error("KaTeX parse error");
          }
          elem.innerHTML = `<span class="katex">${text}</span>`;
        },
      };
    });

    nestedHooks.afterEach(function () {
      this.container.remove();
      window.katex = this.originalKatex;
    });

    test("renders valid math and applies correct classes", async function (assert) {
      this.container.innerHTML = '<span class="math">x^2</span>';

      await renderKatex(this.container);

      const mathElem = this.container.querySelector(".math");
      assert.true(
        mathElem.classList.contains("math-container"),
        "adds math-container class"
      );
      assert.true(
        mathElem.classList.contains("inline-math"),
        "adds inline-math class for span"
      );
      assert.true(
        mathElem.classList.contains("katex-math"),
        "adds katex-math class"
      );
      assert.true(
        !!mathElem.querySelector(".katex"),
        "renders KaTeX content inside element"
      );
    });

    test("renders block math with correct display class", async function (assert) {
      this.container.innerHTML = '<div class="math">\\frac{a}{b}</div>';

      await renderKatex(this.container);

      const mathElem = this.container.querySelector(".math");
      assert.true(
        mathElem.classList.contains("block-math"),
        "adds block-math class for div"
      );
    });

    test("recovers gracefully when KaTeX throws error", async function (assert) {
      this.container.innerHTML =
        '<span class="math">invalid\\syntax\\that\\fails</span>';

      await renderKatex(this.container);

      const mathElem = this.container.querySelector(".math");
      assert.strictEqual(
        mathElem.textContent,
        "invalid\\syntax\\that\\fails",
        "restores original text content"
      );
      assert.false(
        mathElem.classList.contains("katex-math"),
        "removes katex-math class on error"
      );
      assert.false(
        mathElem.classList.contains("math-container"),
        "removes math-container class on error"
      );
    });

    test("skips elements that are not .math", async function (assert) {
      this.container.innerHTML = '<span class="not-math">x^2</span>';

      await renderKatex(this.container);

      const elem = this.container.querySelector(".not-math");
      assert.false(
        elem.classList.contains("katex-math"),
        "does not process non-math elements"
      );
    });

    test("does nothing when container is null", async function (assert) {
      await renderKatex(null);
      assert.true(true, "does not throw when container is null");
    });

    test("force option re-renders already processed elements", async function (assert) {
      this.container.innerHTML = '<span class="math">x^2</span>';

      await renderKatex(this.container);
      const firstRender = this.container.querySelector(".katex").innerHTML;

      this.container.querySelector(".math").textContent = "y^3";
      await renderKatex(this.container, { force: true });

      const secondRender = this.container.querySelector(".katex")?.innerHTML;
      assert.notStrictEqual(
        firstRender,
        secondRender,
        "re-renders with new content when force is true"
      );
    });
  });

  module("buildDiscourseMathOptions", function () {
    test("builds options from site settings", function (assert) {
      const mockSiteSettings = {
        discourse_math_enabled: true,
        discourse_math_provider: "mathjax",
        discourse_math_enable_asciimath: false,
        discourse_math_enable_accessibility: true,
        discourse_math_mathjax_output: "svg",
        discourse_math_zoom_on_click: true,
      };

      const options = buildDiscourseMathOptions(mockSiteSettings);

      assert.true(options.enabled, "enabled is set correctly");
      assert.strictEqual(
        options.provider,
        "mathjax",
        "provider is set correctly"
      );
      assert.false(
        options.enable_asciimath,
        "enable_asciimath is set correctly"
      );
      assert.true(
        options.enable_accessibility,
        "enable_accessibility is set correctly"
      );
      assert.strictEqual(
        options.mathjax_output,
        "svg",
        "mathjax_output is set correctly"
      );
      assert.true(options.zoom_on_click, "zoom_on_click is set correctly");
    });

    test("builds options with katex provider", function (assert) {
      const mockSiteSettings = {
        discourse_math_enabled: true,
        discourse_math_provider: "katex",
        discourse_math_enable_asciimath: true,
        discourse_math_enable_accessibility: false,
        discourse_math_mathjax_output: "html",
        discourse_math_zoom_on_click: false,
      };

      const options = buildDiscourseMathOptions(mockSiteSettings);

      assert.strictEqual(options.provider, "katex", "provider is set to katex");
      assert.true(options.enable_asciimath, "asciimath is enabled");
    });

    test("handles disabled math", function (assert) {
      const mockSiteSettings = {
        discourse_math_enabled: false,
        discourse_math_provider: "mathjax",
        discourse_math_enable_asciimath: false,
        discourse_math_enable_accessibility: false,
        discourse_math_mathjax_output: "html",
        discourse_math_zoom_on_click: false,
      };

      const options = buildDiscourseMathOptions(mockSiteSettings);

      assert.false(options.enabled, "math is disabled");
    });
  });
});
