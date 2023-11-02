import { visit } from "@ember/test-helpers";
import { test } from "qunit";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

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
      ":root {\n--category-1-color: #ff0000;\n--category-2-color: #333;\n--category-4-color: #2B81AF;\n}"
    );
  });

  test("hashtag CSS classes are generated", async function (assert) {
    await visit("/");
    const cssTag = document.querySelector("style#hashtag-css-generator");
    assert.equal(
      cssTag.innerHTML,
      ".hashtag-color--category-1 {\n  background: linear-gradient(-90deg, var(--category-1-color) 50%, var(--category-1-color) 50%);\n}\n.hashtag-color--category-2 {\n  background: linear-gradient(-90deg, var(--category-2-color) 50%, var(--category-2-color) 50%);\n}\n.hashtag-color--category-4 {\n  background: linear-gradient(-90deg, var(--category-4-color) 50%, var(--category-1-color) 50%);\n}"
    );
  });

  test("category badge CSS variables are generated", async function (assert) {
    await visit("/");
    const cssTag = document.querySelector("style#category-badge-css-generator");
    assert.ok(
      cssTag.innerHTML.includes(
        '.badge-category[data-category="1"] { --category-badge-color: var(--category-1-color); --category-badge-text-color: #ffffff; }'
      )
    );
  });
});
