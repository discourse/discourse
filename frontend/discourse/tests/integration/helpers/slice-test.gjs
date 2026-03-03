import { run } from "@ember/runloop";
import { render } from "@ember/test-helpers";
import { TrackedArray } from "@ember-compat/tracked-built-ins";
import { setupRenderingTest } from "ember-qunit";
import { module, test } from "qunit";
import slice from "discourse/helpers/slice";

module("Integration | Helper | {{slice}}", function (hooks) {
  setupRenderingTest(hooks);

  test("it slices an array with positional params", async function (assert) {
    const array = [2, 4, 6];

    await render(<template>{{slice 1 3 array}}</template>);

    assert.dom().hasText("4,6", "sliced values");
  });

  test("it slices when only 2 params are passed", async function (assert) {
    const array = [2, 4, 6];

    await render(<template>{{slice 1 array}}</template>);

    assert.dom().hasText("4,6", "sliced values");
  });

  test("it recomputes the slice if an item in the array changes", async function (assert) {
    let array = new TrackedArray([2, 4, 6]);
    this.set("array", array);

    await render(<template>{{slice 1 3 this.array}}</template>);

    assert.dom().hasText("4,6", "sliced values");

    run(() => array.splice(2, 1, 5));

    assert.dom().hasText("4,5", "sliced values");
  });

  test("it allows null array", async function (assert) {
    await render(
      <template>
        this is all that will render
        {{#each (slice 1 2 null) as |value|}}
          {{value}}
        {{/each}}
      </template>
    );

    assert.dom().hasText("this is all that will render", "no error is thrown");
  });

  test("it allows undefined array", async function (assert) {
    await render(
      <template>
        this is all that will render
        {{#each (slice 1 2 undefined) as |value|}}
          {{value}}
        {{/each}}
      </template>
    );

    assert.dom().hasText("this is all that will render", "no error is thrown");
  });
});
