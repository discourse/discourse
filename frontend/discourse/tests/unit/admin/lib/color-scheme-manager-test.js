import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import {
  applyColorScheme,
  setDefaultColorScheme,
} from "discourse/admin/lib/color-scheme-manager";
import pretender, { response } from "discourse/tests/helpers/create-pretender";

const ORIGINAL_LIGHT_HREF = "data:text/css,original-light";
const ORIGINAL_DARK_HREF = "data:text/css,original-dark";

function stylesheetLink(className, href) {
  const link = document.createElement("link");
  link.rel = "stylesheet";
  link.className = className;
  link.href = href;
  return link;
}

function previewResponse(request) {
  const [, id] = request.url.match(/color-scheme-stylesheet\/(-?\d+)/);
  return response({
    color_scheme_id: Number(id),
    new_href: `data:text/css,preview-${id}`,
  });
}

module("Unit | Admin | Lib | color-scheme-manager", function (hooks) {
  setupTest(hooks);

  hooks.beforeEach(function () {
    this.lightLink = stylesheetLink("light-scheme", ORIGINAL_LIGHT_HREF);
    this.darkLink = stylesheetLink("dark-scheme", ORIGINAL_DARK_HREF);
    document.head.prepend(this.darkLink);
    document.head.prepend(this.lightLink);

    pretender.get("/color-scheme-stylesheet/:id", previewResponse);
    pretender.get("/color-scheme-stylesheet/:id/:themeId", previewResponse);
  });

  hooks.afterEach(function () {
    this.lightLink.remove();
    this.darkLink.remove();
  });

  test("applyColorScheme replaces the light stylesheet in light mode", async function (assert) {
    await applyColorScheme(
      { id: 41 },
      { replace: true, themeId: -1, mode: "light" }
    );

    assert
      .dom(this.lightLink)
      .hasAttribute(
        "href",
        "data:text/css,preview-41",
        "updates the light link"
      );
    assert
      .dom(this.darkLink)
      .hasAttribute(
        "href",
        ORIGINAL_DARK_HREF,
        "leaves the dark link unchanged"
      );
  });

  test("applyColorScheme replaces the dark stylesheet in dark mode", async function (assert) {
    await applyColorScheme(
      { id: 42 },
      { replace: true, themeId: -1, mode: "dark" }
    );

    assert
      .dom(this.darkLink)
      .hasAttribute(
        "href",
        "data:text/css,preview-42",
        "updates the dark link"
      );
    assert
      .dom(this.lightLink)
      .hasAttribute(
        "href",
        ORIGINAL_LIGHT_HREF,
        "leaves the light link unchanged"
      );
  });

  test("setDefaultColorScheme previews and saves the selected mode", async function (assert) {
    const updateCalls = [];
    const scheme = {
      id: 43,
      is_base: false,
      updateDefaultOnTheme(...args) {
        updateCalls.push(args);
      },
    };
    const defaultTheme = {
      color_scheme_id: 1,
      dark_color_scheme_id: 2,
    };

    await setDefaultColorScheme(scheme, defaultTheme, { mode: "dark" });

    assert
      .dom(this.darkLink)
      .hasAttribute(
        "href",
        "data:text/css,preview-43",
        "previews on the dark link"
      );
    assert.deepEqual(
      updateCalls,
      [["default_dark_on_theme", true]],
      "marks the scheme as the dark default"
    );
    assert.strictEqual(
      defaultTheme.dark_color_scheme_id,
      43,
      "updates the theme's dark scheme"
    );
  });
});
