import Component from "@glimmer/component";
import { createCache, getValue } from "@glimmer/tracking/primitives/cache";
import {
  associateDestroyableChild,
  destroy,
  registerDestructor,
} from "@ember/destroyable";
import { render, settled } from "@ember/test-helpers";
import { TrackedObject } from "@ember-compat/tracked-built-ins";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

import { cell, resource, resourceFactory, use } from "ember-resources";

module("ember-resources", function (hooks) {
  setupRenderingTest(hooks);

  test("d-resource usage in a template", async function (assert) {
    const state = new TrackedObject();

    let evaluateCount = 0;
    let cleanupCount = 0;

    class MyComponent extends Component {
      resource = resourceFactory(() =>
        resource(({ on }) => {
          evaluateCount++;
          on.cleanup(() => cleanupCount++);
          return this.args.input;
        })
      );

      <template>
        {{this.resource}}
      </template>
    }

    await render(<template><MyComponent @input={{state.foo}} /></template>);

    assert.strictEqual(
      evaluateCount,
      1,
      "it evaluates the resource for the first time"
    );
    assert.strictEqual(cleanupCount, 0, "no cleanup yet");

    state.foo = "bar";

    await settled();

    assert.strictEqual(
      evaluateCount,
      2,
      "re-evaluates after changing argument"
    );
    assert.strictEqual(cleanupCount, 1, "cleans up the first lifetime");

    await render(<template>empty</template>);

    assert.strictEqual(
      evaluateCount,
      2,
      "no more evaluations after destruction"
    );
    assert.strictEqual(cleanupCount, 2, "destroys final lifetime correctly");
  });

  test("d-resource usage without template reference", async function (assert) {
    const state = new TrackedObject();

    let evaluateCount = 0;
    let cleanupCount = 0;

    class MyComponent extends Component {
      resource = use(
        this,
        resource(({ on }) => {
          evaluateCount++;
          on.cleanup(() => cleanupCount++);
          return this.args.input;
        })
      );

      <template>
        No reference to resource in template
      </template>
    }

    await render(<template><MyComponent @input={{state.foo}} /></template>);

    assert.strictEqual(
      evaluateCount,
      1,
      "it evaluates the resource for the first time"
    );
    assert.strictEqual(cleanupCount, 0, "no cleanup yet");

    state.foo = "bar";

    await settled();

    assert.strictEqual(
      evaluateCount,
      2,
      "re-evaluates after changing argument"
    );
    assert.strictEqual(cleanupCount, 1, "cleans up the first lifetime");

    await render(<template>empty</template>);

    assert.strictEqual(
      evaluateCount,
      2,
      "no more evaluations after destruction"
    );
    assert.strictEqual(cleanupCount, 2, "destroys final lifetime correctly");
  });
});
