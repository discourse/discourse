import { visit } from "@ember/test-helpers";
import { test } from "qunit";
import { acceptance, exists } from "discourse/tests/helpers/qunit-helpers";

acceptance("CSS Generator", function (needs) {
  needs.user();

  needs.site({
    categories: [
      { id: 1, color: "ff0000", text_color: "ffffff", name: "category1" },
      { id: 2, color: "333", text_color: "ffffff", name: "category2" },
      {
        id: 4,
        color: "2B81AF",
        text_color: "ffffff",
        parentCategory: { id: 1 },
        name: "category3",
      },
    ],
  });

  test("category CSS variables are generated", async function (assert) {
    await visit("/");
    const cssTag = document.querySelector("style#category-color-css-generator");
    assert.equal(
      cssTag.innerHTML,
      ":root {\n" +
        "--category-1-color: #ff0000;\n" +
        "--category-2-color: #333;\n" +
        "--category-4-color: #2B81AF;\n" +
        "}"
    );
  });

  test("hashtag CSS classes are generated", async function (assert) {
    await visit("/");
    const cssTag = document.querySelector("style#hashtag-css-generator");
    assert.equal(
      cssTag.innerHTML,
      ".hashtag-category-badge { background-color: var(--primary-medium); }\n" +
        ".hashtag-color--category-1 { background-color: #ff0000; }\n" +
        ".hashtag-color--category-2 { background-color: #333; }\n" +
        ".hashtag-color--category-4 { background-color: #2B81AF; }"
    );
  });

  test("category badge CSS variables are generated", async function (assert) {
    await visit("/");
    const cssTag = document.querySelector("style#category-badge-css-generator");
    assert.equal(
      cssTag.innerHTML,
      '.badge-category[data-category-id="1"] { --category-badge-color: var(--category-1-color); --category-badge-text-color: #ffffff; }\n' +
        '.badge-category[data-category-id="2"] { --category-badge-color: var(--category-2-color); --category-badge-text-color: #ffffff; }\n' +
        '.badge-category[data-category-id="4"] { --category-badge-color: var(--category-4-color); --category-badge-text-color: #ffffff; }'
    );
  });
});

acceptance(
  "CSS Generator | Anon user in login_required site",
  function (needs) {
    needs.site({ categories: null });
    needs.settings({ login_required: true });
    test("category CSS variables are not generated", async function (assert) {
      await visit("/");

      const cssTag = document.querySelector(
        "style#category-color-css-generator"
      );
      assert.notOk(exists(cssTag));
    });

    test("category badge CSS variables are not generated", async function (assert) {
      await visit("/");
      const cssTag = document.querySelector(
        "style#category-badge-css-generator"
      );
      assert.notOk(exists(cssTag));
    });
  }
);
