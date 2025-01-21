import { triggerKeyEvent } from "@ember/test-helpers";
import { setupTest } from "ember-qunit";
import { compile } from "handlebars";
import $ from "jquery";
import { module, test } from "qunit";
import { setCaretPosition } from "discourse/lib/utilities";
import {
  simulateKey,
  simulateKeys,
} from "discourse/tests/helpers/qunit-helpers";

module("Unit | Utility | autocomplete", function (hooks) {
  setupTest(hooks);

  let _element;

  const template = compile(
    `
  <div id='ac-testing' class='autocomplete ac-test'>
    <ul>
      {{#each options as |option|}}
        <li><a href>{{option}}</a></li>
      {{/each}}
    </ul>
  </div>
  `.trim()
  );

  function textArea() {
    _element = document.createElement("TEXTAREA");
    document.getElementById("ember-testing").appendChild(_element);
    return _element;
  }

  hooks.afterEach(() => {
    if (!_element) {
      return;
    }
    const $e = $(_element);
    $e.autocomplete({ cancel: true });
    $e.autocomplete("destroy");
    _element.remove();
  });

  test("Autocomplete can complete really short terms correctly", async function (assert) {
    const element = textArea();

    $(element).autocomplete({
      key: ":",
      template,
      transformComplete: (e) => e.slice(1),
      dataSource: () => [":sad:"],
    });

    await simulateKeys(element, "a :)\r");

    assert.dom(element).hasValue("a :sad: ");
    assert.strictEqual(element.selectionStart, 8);
    assert.strictEqual(element.selectionEnd, 8);
  });

  test("Autocomplete can account for cursor drift correctly", async function (assert) {
    const element = textArea();
    const db = ["test1", "test2"];

    $(element).autocomplete({
      key: "@",
      template,
      dataSource: (term) => db.filter((word) => word.includes(term)),
    });

    await simulateKeys(element, "@\r");

    assert.dom(element).hasValue("@test1 ");
    assert.strictEqual(element.selectionStart, 7);
    assert.strictEqual(element.selectionEnd, 7);

    await simulateKeys(element, "@2\r");

    assert.dom(element).hasValue("@test1 @test2 ");
    assert.strictEqual(element.selectionStart, 14);
    assert.strictEqual(element.selectionEnd, 14);

    await setCaretPosition(element, 6);
    await simulateKeys(element, "\b\b");

    assert.dom(element).hasValue("@tes @test2 ");

    await simulateKey(element, "\r");

    assert.dom(element).hasValue("@test1 @test2 ");
    assert.strictEqual(element.selectionStart, 7);
    assert.strictEqual(element.selectionEnd, 7);

    // ensures that deleting last space triggers autocomplete
    await setCaretPosition(element, element.value.length);
    await simulateKey(element, "\b");

    assert.dom("#ac-testing ul li").exists({ count: 1 });

    await simulateKey(element, "\b");

    assert.dom("#ac-testing ul li").exists({ count: 2 });

    // close autocomplete
    await simulateKey(element, "\r");

    // does not trigger by mistake at the start
    element.value = "test";

    await setCaretPosition(element, element.value.length);
    await simulateKey(element, "\b");

    assert.dom("#ac-testing ul li").exists({ count: 0 });
  });

  test("Autocomplete can handle spaces", async function (assert) {
    const element = textArea();
    const db = [
      { username: "jd", name: "jane dale" },
      { username: "jb", name: "jack black" },
    ];

    $(element).autocomplete({
      key: "@",
      template,
      dataSource: (term) =>
        db
          .filter(
            (user) => user.username.includes(term) || user.name.includes(term)
          )
          .map((user) => user.username),
    });

    await simulateKeys(element, "@jane d\r");

    assert.dom(element).hasValue("@jd ");
  });

  test("Autocomplete can render on @", async function (assert) {
    const element = textArea();

    $(element).autocomplete({
      key: "@",
      template,
      dataSource: () => ["test1", "test2"],
    });

    await simulateKey(element, "@");

    assert.dom("#ac-testing ul li").exists({ count: 2 });
    assert.dom("#ac-testing li a.selected").exists({ count: 1 });
    assert.dom("#ac-testing li a.selected").hasText("test1");
  });

  test("Autocomplete doesn't reset undo history", async function (assert) {
    const element = textArea();

    $(element).autocomplete({
      key: "@",
      template,
      dataSource: () => ["test1", "test2"],
    });

    await simulateKeys(element, "@t\r");

    assert.strictEqual(element.value, "@test1 ");

    document.execCommand("undo");

    assert.strictEqual(element.value, "@t");
  });

  test("Autocomplete does not trigger with right-left arrow keys", async function (assert) {
    const element = textArea();

    $(element).autocomplete({
      key: ":",
      template,
      transformComplete: (e) => e.slice(1),
      dataSource: () => [":smile:"],
    });

    await simulateKeys(element, ":smi\t");

    assert.dom(element).hasValue(":smile: ");

    await triggerArrowKey(element, "ArrowLeft");
    await triggerArrowKey(element, "ArrowLeft");
    await triggerArrowKey(element, "ArrowLeft");
    await triggerArrowKey(element, "ArrowRight");

    assert.strictEqual(element.selectionStart, 6);

    // This is passing, but it's a false positive
    // triggerArrowKey isn't triggering the event the autocomplete listens to
    assert.dom("#ac-testing").doesNotExist();

    await triggerArrowKey(element, "ArrowRight");
    await simulateKey(element, "\b");

    assert.dom(element).hasValue(":smile ");
    assert.dom("#ac-testing").exists();
  });
});

async function triggerArrowKey(element, key) {
  await triggerKeyEvent(element, "keydown", key, { code: key });
  await triggerKeyEvent(element, "keyup", key, { code: key });

  const pos = element.selectionStart;
  const direction = key === "ArrowLeft" ? -1 : 1;
  element.setSelectionRange(pos + 1 * direction, pos + 1 * direction);
}
