import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import SeparatedList from "discourse/components/separated-list";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

module("Integration | Component | separated-list", function (hooks) {
  setupRenderingTest(hooks);

  test("renders items with default separator", async function (assert) {
    this.items = ["apple", "banana", "cherry"];

    await render(
      <template>
        <SeparatedList @items={{this.items}} as |item|>
          {{item}}
        </SeparatedList>
      </template>
    );

    assert.dom(this.element).hasText("apple, banana, cherry");
  });

  test("renders items with custom separator", async function (assert) {
    this.items = ["apple", "banana", "cherry"];
    this.separator = " | ";

    await render(
      <template>
        <SeparatedList
          @items={{this.items}}
          @separator={{this.separator}}
          as |item|
        >
          {{item}}
        </SeparatedList>
      </template>
    );

    assert.dom(this.element).hasText("apple | banana | cherry");
  });

  test("renders single item without separator", async function (assert) {
    this.items = ["apple"];

    await render(
      <template>
        <SeparatedList @items={{this.items}} as |item|>
          {{item}}
        </SeparatedList>
      </template>
    );

    assert.dom(this.element).hasText("apple");
  });

  test("renders empty array", async function (assert) {
    this.items = [];

    await render(
      <template>
        <SeparatedList @items={{this.items}} as |item|>
          {{item}}
        </SeparatedList>
      </template>
    );

    assert.dom(this.element).hasText("");
  });

  test("yields index to block", async function (assert) {
    this.items = ["apple", "banana"];

    await render(
      <template>
        <SeparatedList @items={{this.items}} as |item index|>
          {{item}}[{{index}}]
        </SeparatedList>
      </template>
    );

    assert.dom(this.element).hasText("apple[0], banana[1]");
  });
});
