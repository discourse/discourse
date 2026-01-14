import { visit } from "@ember/test-helpers";
import { test } from "qunit";
import Session from "discourse/models/session";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

const SITE_DATA = {
  categories: [
    {
      id: 1,
      color: "ff0000",
      text_color: "ffffff",
      name: "category1",
      slug: "foo",
      uploaded_background: {
        id: 54,
        url: "/uploads/default/original/1X/c5c84b16ebf745ab848d1498267c541facbf1ff0.png",
        width: 1024,
        height: 768,
      },
    },
    {
      id: 2,
      color: "333",
      text_color: "ffffff",
      name: "category2",
      slug: "bar",
      uploaded_background_dark: {
        id: 25,
        url: "/uploads/default/original/1X/f9fdb0ad108f2aed178c40f351bbb2c7cb2571e3.png",
        width: 1024,
        height: 768,
      },
    },
    {
      id: 4,
      color: "2B81AF",
      text_color: "ffffff",
      parent_category_id: 1,
      name: "category3",
      slug: "baz",
      uploaded_background: {
        id: 11,
        url: "/uploads/default/original/1X/684c104edc18a7e9cef1fa31f41215f3eec5d92b.png",
        width: 1024,
        height: 768,
      },
      uploaded_background_dark: {
        id: 19,
        url: "/uploads/default/original/1X/89b1a2641e91604c32b21db496be11dba7a253e6.png",
        width: 1024,
        height: 768,
      },
    },
  ],
};

acceptance("DStyles - category backgrounds", function (needs) {
  needs.user();
  needs.site(SITE_DATA);

  test("CSS classes are generated", async function (assert) {
    await visit("/");

    assert
      .dom("#d-styles")
      .includesHtml(
        "body.category-foo { background-image: url(/uploads/default/original/1X/c5c84b16ebf745ab848d1498267c541facbf1ff0.png); }"
      );
    assert
      .dom("#d-styles")
      .includesHtml(
        "body.category-foo-baz { background-image: url(/uploads/default/original/1X/684c104edc18a7e9cef1fa31f41215f3eec5d92b.png); }"
      );
  });
});

acceptance("DStyles - category backgrounds (dark)", function (needs) {
  needs.user();
  needs.site(SITE_DATA);

  needs.hooks.beforeEach(function () {
    const session = Session.current();
    session.set("darkModeAvailable", true);
    session.set("defaultColorSchemeIsDark", false);
  });

  needs.hooks.afterEach(function () {
    const session = Session.current();
    session.set("darkModeAvailable", null);
    session.set("defaultColorSchemeIsDark", null);
  });

  test("CSS classes are generated", async function (assert) {
    await visit("/");

    const css = [
      "body.category-foo { background-image: url(/uploads/default/original/1X/c5c84b16ebf745ab848d1498267c541facbf1ff0.png); }",
      "body.category-foo-baz { background-image: url(/uploads/default/original/1X/684c104edc18a7e9cef1fa31f41215f3eec5d92b.png); }",
      "@media (prefers-color-scheme: dark) {",
      "body.category-bar { background-image: url(/uploads/default/original/1X/f9fdb0ad108f2aed178c40f351bbb2c7cb2571e3.png); }",
      "body.category-foo-baz { background-image: url(/uploads/default/original/1X/89b1a2641e91604c32b21db496be11dba7a253e6.png); }",
      "}",
    ].join(" ");
    assert.dom("#d-styles").includesHtml(css);
  });
});

acceptance(
  "DStyles - category backgrounds (default theme is dark)",
  function (needs) {
    needs.user();
    needs.site(SITE_DATA);

    needs.hooks.beforeEach(function () {
      const session = Session.current();
      session.set("darkModeAvailable", true);
      session.set("defaultColorSchemeIsDark", true);
    });

    needs.hooks.afterEach(function () {
      const session = Session.current();
      session.set("darkModeAvailable", null);
      session.set("defaultColorSchemeIsDark", null);
    });

    test("CSS classes are generated", async function (assert) {
      await visit("/");

      const css = [
        "body.category-foo { background-image: url(/uploads/default/original/1X/c5c84b16ebf745ab848d1498267c541facbf1ff0.png); }",
        "body.category-bar { background-image: url(/uploads/default/original/1X/f9fdb0ad108f2aed178c40f351bbb2c7cb2571e3.png); }",
        "body.category-foo-baz { background-image: url(/uploads/default/original/1X/89b1a2641e91604c32b21db496be11dba7a253e6.png); }",
      ].join(" ");
      assert.dom("#d-styles").includesHtml(css);
    });
  }
);

acceptance("DStyles - category badges", function (needs) {
  needs.user();

  needs.site({
    categories: [
      { id: 1, color: "ff0000", text_color: "ffffff", name: "category1" },
      { id: 2, color: "333", text_color: "ffffff", name: "category2" },
      {
        id: 4,
        color: "2B81AF",
        text_color: "ffffff",
        parent_category_id: 1,
        name: "category3",
      },
    ],
  });

  test("category CSS variables are generated", async function (assert) {
    await visit("/");

    const css = [
      ":root {",
      "--category-1-color: #ff0000;",
      "--category-2-color: #333;",
      "--category-4-color: #2B81AF;",
      "}",
    ].join(" ");
    assert.dom("style#d-styles").includesHtml(css);
  });

  test("category badge CSS variables are generated", async function (assert) {
    await visit("/");

    const css = [
      '.badge-category[data-category-id="1"] { --category-badge-color: var(--category-1-color); --category-badge-text-color: #ffffff; }',
      '.badge-category[data-parent-category-id="1"] { --parent-category-badge-color: var(--category-1-color); }',
      '.badge-category[data-category-id="2"] { --category-badge-color: var(--category-2-color); --category-badge-text-color: #ffffff; }',
      '.badge-category[data-category-id="4"] { --category-badge-color: var(--category-4-color); --category-badge-text-color: #ffffff; }',
    ].join(" ");
    assert.dom("style#d-styles").includesHtml(css);
  });
});
