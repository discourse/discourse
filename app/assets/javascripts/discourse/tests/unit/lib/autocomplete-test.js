import { module, test } from "qunit";
import autocomplete from "discourse/lib/autocomplete";
import { compile } from "handlebars";

module("Unit | Utility | autocomplete", function (hooks) {
  let elements = [];

  function textArea(value) {
    let element = document.createElement("TEXTAREA");
    element.value = value;
    document.getElementById("ember-testing").appendChild(element);
    elements.push(element);
    return element;
  }

  function cleanup() {
    elements.forEach((e) => {
      e.remove();
      autocomplete.call($(e), { cancel: true });
      autocomplete.call($(e), "destroy");
    });
    elements = [];
  }

  hooks.afterEach(function () {
    cleanup();
  });

  function simulateKey(element, key) {
    let keyCode = key.charCodeAt(0);

    let bubbled = false;
    let trackBubble = function () {
      bubbled = true;
    };

    element.addEventListener("keydown", trackBubble);

    let keyboardEvent = new KeyboardEvent("keydown", {
      key,
      keyCode,
      which: keyCode,
    });

    element.dispatchEvent(keyboardEvent);

    element.removeEventListener("keydown", trackBubble);

    if (bubbled) {
      let pos = element.selectionStart;
      let value = element.value;
      // backspace
      if (key === "\b") {
        element.value = value.slice(0, pos - 1) + value.slice(pos);
        element.selectionStart = pos - 1;
        element.selectionEnd = pos - 1;
      } else {
        element.value = value.slice(0, pos) + key + value.slice(pos);
        element.selectionStart = pos + 1;
        element.selectionEnd = pos + 1;
      }
    }

    element.dispatchEvent(
      new KeyboardEvent("keyup", { key, keyCode, which: keyCode })
    );
  }

  test("Autocomplete can account for cursor drift correctly", function (assert) {
    let element = textArea("");
    let $element = $(element);

    autocomplete.call($element, {
      key: "@",
      dataSource: (term) =>
        ["test1", "test2"].filter((word) => word.includes(term)),
      template: compile(`<div id='ac-testing' class='autocomplete ac-test'>
  <ul>
    {{#each options as |option|}}
      <li>
        <a href>
          {{option}}
        </a>
      </li>
    {{/each}}
  </ul>
</div>`),
    });

    simulateKey(element, "@");
    simulateKey(element, "\r");

    assert.strictEqual(element.value, "@test1 ");
    assert.strictEqual(element.selectionStart, 7);
    assert.strictEqual(element.selectionEnd, 7);

    simulateKey(element, "@");
    simulateKey(element, "2");
    simulateKey(element, "\r");

    assert.strictEqual(element.value, "@test1 @test2 ");
    assert.strictEqual(element.selectionStart, 14);
    assert.strictEqual(element.selectionEnd, 14);

    element.selectionStart = 6;
    element.selectionEnd = 6;

    simulateKey(element, "\b");
    simulateKey(element, "\b");
    simulateKey(element, "\r");

    assert.strictEqual(element.value, "@test1 @test2 ");
    assert.strictEqual(element.selectionStart, 7);
    assert.strictEqual(element.selectionEnd, 7);

    // lets see that deleting last space triggers autocomplete
    element.selectionStart = element.value.length;
    element.selectionEnd = element.value.length;
    simulateKey(element, "\b");
    let list = document.querySelectorAll("#ac-testing ul li");
    assert.strictEqual(list.length, 1);

    simulateKey(element, "\b");
    list = document.querySelectorAll("#ac-testing ul li");
    assert.strictEqual(list.length, 2);

    // close autocomplete
    simulateKey(element, "\r");

    // does not trigger by mistake at the start
    element.value = "test";
    element.selectionStart = element.value.length;
    element.selectionEnd = element.value.length;

    simulateKey(element, "\b");
    list = document.querySelectorAll("#ac-testing ul li");
    assert.strictEqual(list.length, 0);
  });

  test("Autocomplete can handle spaces", function (assert) {
    let element = textArea("");
    let $element = $(element);

    autocomplete.call($element, {
      key: "@",
      dataSource: (term) =>
        [
          { username: "jd", name: "jane dale" },
          { username: "jb", name: "jack black" },
        ]
          .filter((user) => {
            return user.username.includes(term) || user.name.includes(term);
          })
          .map((user) => user.username),
      template: compile(`<div id='ac-testing' class='autocomplete ac-test'>
  <ul>
    {{#each options as |option|}}
      <li>
        <a href>
          {{option}}
        </a>
      </li>
    {{/each}}
  </ul>
</div>`),
    });

    simulateKey(element, "@");
    simulateKey(element, "j");
    simulateKey(element, "a");
    simulateKey(element, "n");
    simulateKey(element, "e");
    simulateKey(element, " ");
    simulateKey(element, "d");
    simulateKey(element, "\r");

    assert.strictEqual(element.value, "@jd ");
  });

  test("Autocomplete can render on @", function (assert) {
    let element = textArea("@");
    let $element = $(element);

    autocomplete.call($element, {
      key: "@",
      dataSource: () => ["test1", "test2"],
      template: compile(`<div id='ac-testing' class='autocomplete ac-test'>
  <ul>
    {{#each options as |option|}}
      <li>
        <a href>
          {{option}}
        </a>
      </li>
    {{/each}}
  </ul>
</div>`),
    });

    element.dispatchEvent(new KeyboardEvent("keydown", { key: "@" }));
    element.dispatchEvent(new KeyboardEvent("keyup", { key: "@" }));

    let list = document.querySelectorAll("#ac-testing ul li");
    assert.strictEqual(2, list.length);

    let selected = document.querySelectorAll("#ac-testing ul li a.selected");
    assert.strictEqual(1, selected.length);
    assert.strictEqual("test1", selected[0].innerText);
  });
});
