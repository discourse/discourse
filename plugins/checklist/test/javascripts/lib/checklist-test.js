import { click, settled } from "@ember/test-helpers";
import { test } from "qunit";
import { cook } from "discourse/lib/text";
import Post from "discourse/models/post";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";
import { checklistSyntax } from "discourse/plugins/checklist/discourse/initializers/checklist";

let lastToggleRequest;
let respondWithError;

async function prepare(raw) {
  const cooked = await cook(raw, {
    siteSettings: {
      checklist_enabled: true,
      discourse_local_dates_enabled: true,
    },
  });

  const widget = { attrs: {}, scheduleRerender() {} };
  const model = Post.create({ id: 42, can_edit: true });
  const decoratorHelper = { widget, getModel: () => model };

  const element = document.createElement("div");
  element.innerHTML = cooked.toString();
  checklistSyntax(element, decoratorHelper);

  document.querySelector("#ember-testing").append(element);
}

acceptance("checklist", function (needs) {
  needs.pretender((server, helper) => {
    server.put("/checklist/toggle", (request) => {
      const params = new URLSearchParams(request.requestBody);
      lastToggleRequest = {
        post_id: parseInt(params.get("post_id"), 10),
        checkbox_index: parseInt(params.get("checkbox_index"), 10),
        checkbox_count: parseInt(params.get("checkbox_count"), 10),
        checked: params.get("checked") === "true",
      };

      if (respondWithError) {
        return helper.response(422, {});
      }

      return helper.response(204, "");
    });
  });

  needs.hooks.beforeEach(function () {
    lastToggleRequest = null;
    respondWithError = false;
  });

  needs.hooks.afterEach(function () {
    document.querySelector("#ember-testing").innerHTML = "";
  });

  test("sends the correct index and count", async function (assert) {
    await prepare(`
\`[x]\`
*[x]*
**[x]**
_[x]_
__[x]__
~~[x]~~

[code]
[x]
[ ]
[ ]
[x]
[/code]

\`\`\`
[x]
[ ]
[ ]
[x]
\`\`\`

Actual checkboxes:
[] first
[x] second
* test[x]*third*
[x] fourth
[x] fifth
    `);

    assert.dom(".chcklst-box").exists({ count: 5 });

    await click([...document.querySelectorAll(".chcklst-box")][3]);

    assert.deepEqual(lastToggleRequest, {
      post_id: 42,
      checkbox_index: 3,
      checkbox_count: 5,
      checked: false,
    });
  });

  test("does not clash with date-range bbcode", async function (assert) {
    await prepare(`
[date-range from=2024-03-22 to=2024-03-23]

[ ] task 1
[ ] task 2
[x] task 3
    `);

    assert.dom(".discourse-local-date").exists({ count: 2 });
    assert.dom(".chcklst-box").exists({ count: 3 });

    await click(".chcklst-box");

    assert.deepEqual(lastToggleRequest, {
      post_id: 42,
      checkbox_index: 0,
      checkbox_count: 3,
      checked: true,
    });
  });

  test("permanent checkbox is not clickable", async function (assert) {
    await prepare(`
[X] permanent
[x] regular
    `);

    const boxes = [...document.querySelectorAll(".chcklst-box")];

    await click(boxes[0]);
    assert.strictEqual(lastToggleRequest, null);

    await click(boxes[1]);
    assert.deepEqual(lastToggleRequest, {
      post_id: 42,
      checkbox_index: 1,
      checkbox_count: 2,
      checked: false,
    });
  });

  test("checkboxes are readonly while updating and restored after", async function (assert) {
    await prepare(`
[ ] first
[x] second
    `);

    const [checkbox1, checkbox2] = [
      ...document.querySelectorAll(".chcklst-box"),
    ];
    checkbox1.click();

    assert.dom(checkbox1).hasClass("hidden");
    assert.dom(checkbox2).hasClass("readonly");
    assert.dom(".fa-spin").exists();

    await settled();

    assert.dom(checkbox1).hasClass("checked");
    assert.dom(checkbox1).doesNotHaveClass("hidden");
    assert.dom(checkbox1).doesNotHaveClass("readonly");
    assert.dom(checkbox2).doesNotHaveClass("readonly");
    assert.dom(".fa-spin").doesNotExist();
  });

  test("reverts the optimistic state on error", async function (assert) {
    respondWithError = true;

    await prepare(`
[ ] first
[x] second
    `);

    const checkbox = document.querySelector(".chcklst-box");
    await click(checkbox);

    assert.dom(checkbox).doesNotHaveClass("checked");
    assert.dom(checkbox).doesNotHaveClass("hidden");
    assert.dom(checkbox).doesNotHaveClass("readonly");
    assert.dom(".fa-spin").doesNotExist();
  });

  test("rendering in bullet lists", async function (assert) {
    await prepare(`
- [ ] LI 1
- LI 2 [ ] with checkbox in middle
- [ ] LI 3

1. [ ] Ordered LI with checkbox
    `);

    assert.dom("ul > li").exists({ count: 3 });
    const listItems = [...document.querySelectorAll("ul > li")];

    assert.dom(listItems[0]).hasClass("has-checkbox");
    assert.dom(".chcklst-box", listItems[0]).hasClass("list-item-checkbox");

    assert.dom(listItems[1]).doesNotHaveClass("has-checkbox");
    assert
      .dom(".chcklst-box", listItems[1])
      .doesNotHaveClass("list-item-checkbox");

    assert.dom(listItems[2]).hasClass("has-checkbox");
    assert.dom(".chcklst-box", listItems[2]).hasClass("list-item-checkbox");

    assert.dom("ol > li").exists({ count: 1 });
    assert.dom("ol > li").doesNotHaveClass("has-checkbox");
    assert.dom("ol .chcklst-box").doesNotHaveClass("list-item-checkbox");
  });
});
