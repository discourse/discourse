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

  test("Autocomplete can account for cursor drift correctly", function (assert) {
    let element = textArea("01234 @");
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

    element.value = "0123456 @t hello";

    element.setSelectionRange(9, 9);

    element.dispatchEvent(new KeyboardEvent("keydown", { key: "t" }));
    element.dispatchEvent(new KeyboardEvent("keyup", { key: "t" }));

    element.dispatchEvent(
      new KeyboardEvent("keydown", { key: "\n", keyCode: 13 })
    );
    element.dispatchEvent(
      new KeyboardEvent("keyup", { key: "\n", keyCode: 13 })
    );

    assert.strictEqual(element.value, "0123456 @test1  hello");
    assert.strictEqual(15, element.selectionStart);
    assert.strictEqual(15, element.selectionEnd);
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
