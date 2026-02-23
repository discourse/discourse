import { click, settled } from "@ember/test-helpers";
import { test } from "qunit";
import { cook } from "discourse/lib/text";
import Post from "discourse/models/post";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";
import { checklistSyntax } from "discourse/plugins/checklist/discourse/initializers/checklist";

let currentRaw;
let lastToggleRequest;

async function prepare(raw) {
  currentRaw = raw;
  lastToggleRequest = null;

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

function computeExpectedRaw(offset, raw) {
  const checkbox = raw.slice(offset, offset + 3);
  const isChecked = checkbox === "[x]";
  const newValue = isChecked ? "[ ]" : "[x]";
  return raw.slice(0, offset) + newValue + raw.slice(offset + 3);
}

acceptance("discourse-checklist | checklist", function (needs) {
  needs.pretender((server, helper) => {
    server.get("/posts/42", () => helper.response({ raw: currentRaw }));
    server.put("/checklist/toggle", (request) => {
      const params = new URLSearchParams(request.requestBody);
      lastToggleRequest = {
        post_id: parseInt(params.get("post_id"), 10),
        checkbox_offset: parseInt(params.get("checkbox_offset"), 10),
      };
      return helper.response({ checked: true, post_id: 42 });
    });
  });

  needs.hooks.afterEach(function () {
    document.querySelector("#ember-testing").innerHTML = "";
  });

  test("does not clash with date-range bbcode", async function (assert) {
    const raw = `
[date-range from=2024-03-22 to=2024-03-23]

[ ] task 1
[ ] task 2
[x] task 3
    `;
    await prepare(raw);

    assert.dom(".discourse-local-date").exists({ count: 2 });
    assert.dom(".chcklst-box").exists({ count: 3 });
    await click(".chcklst-box");

    const output = computeExpectedRaw(lastToggleRequest.checkbox_offset, raw);
    assert.true(output.includes("[x] task 1"));
  });

  test("checkboxes are readonly while updating", async function (assert) {
    const raw = `
[ ] first
[x] second
    `;
    await prepare(raw);

    const [checkbox1, checkbox2] = [
      ...document.querySelectorAll(".chcklst-box"),
    ];
    checkbox1.click();

    assert.dom(checkbox2).hasClass("readonly");
    await settled();

    const output = computeExpectedRaw(lastToggleRequest.checkbox_offset, raw);
    assert.true(output.includes("[x] first"));
    assert.true(output.includes("[x] second"));
  });

  test("correct checkbox is selected", async function (assert) {
    const raw = `
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
[ ] first
[x] second
* test[x]*third*
[x] fourth
[x] fifth
    `;
    await prepare(raw);

    assert.dom(".chcklst-box").exists({ count: 5 });
    await click([...document.querySelectorAll(".chcklst-box")][3]);

    const output = computeExpectedRaw(lastToggleRequest.checkbox_offset, raw);
    assert.true(output.includes("[ ] fourth"));
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
