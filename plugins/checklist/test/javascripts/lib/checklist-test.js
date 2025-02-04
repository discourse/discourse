import { click } from "@ember/test-helpers";
import { test } from "qunit";
import { Promise } from "rsvp";
import { cook } from "discourse/lib/text";
import Post from "discourse/models/post";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";
import { checklistSyntax } from "discourse/plugins/checklist/discourse/initializers/checklist";

let currentRaw;

async function prepare(raw) {
  currentRaw = raw;

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

  const updated = new Promise((resolve) => {
    model.save = async (fields) => resolve(fields.raw);
  });

  return { updated };
}

acceptance("discourse-checklist | checklist", function (needs) {
  needs.pretender((server, helper) => {
    server.get("/posts/42", () => helper.response({ raw: currentRaw }));
  });

  needs.hooks.afterEach(function () {
    document.querySelector("#ember-testing").innerHTML = "";
  });

  test("does not clash with date-range bbcode", async function (assert) {
    const { updated } = await prepare(`
[date-range from=2024-03-22 to=2024-03-23]

[ ] task 1
[ ] task 2
[x] task 3
    `);

    assert.dom(".discourse-local-date").exists({ count: 2 });
    assert.dom(".chcklst-box").exists({ count: 3 });
    await click(".chcklst-box");

    const output = await updated;
    assert.true(output.includes("[x] task 1"));
  });

  test("does not check an image URL", async function (assert) {
    const { updated } = await prepare(`
![](upload://zLd8FtsWc2ZSg3cZKIhwvhYxTcn.jpg)
[] first
[] second
    `);

    await click(".chcklst-box");

    const output = await updated;
    assert.true(output.includes("[x] first"));
  });

  test("make checkboxes readonly while updating", async function (assert) {
    const { updated } = await prepare(`
[ ] first
[x] second
    `);

    const [checkbox1, checkbox2] = [
      ...document.querySelectorAll(".chcklst-box"),
    ];
    checkbox1.click();

    assert.dom(checkbox2).hasClass("readonly");
    await click(checkbox2);

    const output = await updated;
    assert.true(output.includes("[x] first"));
    assert.true(output.includes("[x] second"));
  });

  test("checkbox before a code block", async function (assert) {
    const { updated } = await prepare(`
[ ] first
[x] actual
\`[x] nope\`
    `);

    assert.dom(".chcklst-box").exists({ count: 2 });

    await click([...document.querySelectorAll(".chcklst-box")][1]);

    const output = await updated;
    assert.true(output.includes("[ ] first"));
    assert.true(output.includes("[ ] actual"));
    assert.true(output.includes("[x] nope"));
  });

  test("permanently checked checkbox", async function (assert) {
    const { updated } = await prepare(`
[X] permanent
[x] not permanent
    `);

    assert.dom(".chcklst-box").exists({ count: 2 });

    const [checkbox1, checkbox2] = [
      ...document.querySelectorAll(".chcklst-box"),
    ];

    await click(checkbox1);
    await click(checkbox2);

    const output = await updated;
    assert.true(output.includes("[X] permanent"));
    assert.true(output.includes("[ ] not permanent"));
  });

  test("checkbox before a multiline code block", async function (assert) {
    const { updated } = await prepare(`
[ ] first
[x] actual
\`\`\`
[x] nope
[x] neither
\`\`\`
    `);

    assert.dom(".chcklst-box").exists({ count: 2 });
    await click([...document.querySelectorAll(".chcklst-box")][1]);

    const output = await updated;
    assert.true(output.includes("[ ] first"));
    assert.true(output.includes("[ ] actual"));
    assert.true(output.includes("[x] nope"));
  });

  test("checkbox before italic/bold sequence", async function (assert) {
    const { updated } = await prepare(` [x] *test*`);

    assert.dom(".chcklst-box").exists({ count: 1 });
    await click(".chcklst-box");

    const output = await updated;
    assert.true(output.includes("[ ] *test*"));
  });

  test("checkboxes in an unordered list", async function (assert) {
    const { updated } = await prepare(`
* [x] checked
* [] test
* [] two
  `);

    assert.dom(".chcklst-box").exists({ count: 3 });
    await click([...document.querySelectorAll(".chcklst-box")][1]);

    const output = await updated;
    assert.true(output.includes("* [x] checked"));
    assert.true(output.includes("* [x] test"));
    assert.true(output.includes("* [] two"));
  });

  test("checkboxes in italic/bold-like blocks", async function (assert) {
    const { updated } = await prepare(`
*[x
*a [*] x]*
[*x]
~~[*]~~

* []* 0

~~[] ~~ 1

~~ [x]~~ 2

* [x] 3
  `);

    assert.dom(".chcklst-box").exists({ count: 4 });
    await click([...document.querySelectorAll(".chcklst-box")][3]);

    const output = await updated;
    assert.true(output.includes("* [ ] 3"));
  });

  test("correct checkbox is selected", async function (assert) {
    const { updated } = await prepare(`
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

    const output = await updated;
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
