import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import { buildDiscourseMathOptions } from "discourse/plugins/discourse-math/lib/math-renderer";

module("Unit | Lib | math-renderer", function (hooks) {
  setupTest(hooks);

  module("buildDiscourseMathOptions", function () {
    test("builds options from site settings", function (assert) {
      const mockSiteSettings = {
        discourse_math_enabled: true,
        discourse_math_provider: "mathjax",
        discourse_math_enable_asciimath: false,
        discourse_math_enable_accessibility: true,
        discourse_math_mathjax_output: "svg",
        discourse_math_zoom_on_hover: true,
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
      assert.true(options.zoom_on_hover, "zoom_on_hover is set correctly");
    });

    test("builds options with katex provider", function (assert) {
      const mockSiteSettings = {
        discourse_math_enabled: true,
        discourse_math_provider: "katex",
        discourse_math_enable_asciimath: true,
        discourse_math_enable_accessibility: false,
        discourse_math_mathjax_output: "html",
        discourse_math_zoom_on_hover: false,
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
        discourse_math_zoom_on_hover: false,
      };

      const options = buildDiscourseMathOptions(mockSiteSettings);

      assert.false(options.enabled, "math is disabled");
    });
  });
});
