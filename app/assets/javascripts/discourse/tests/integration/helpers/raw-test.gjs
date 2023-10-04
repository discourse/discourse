import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { render, settled } from "@ember/test-helpers";
import {
  addRawTemplate,
  removeRawTemplate,
} from "discourse-common/lib/raw-templates";
import raw from "discourse/helpers/raw";
import rawRenderGlimmer from "discourse/lib/raw-render-glimmer";
import RenderGlimmerContainer from "discourse/components/render-glimmer-container";
import { tracked } from "@glimmer/tracking";
import { getOwner } from "@ember/application";
import Component from "@glimmer/component";

// We don't have any way to actually compile raw hbs inside tests, so this is only testing
// the helper itself, not the actual rendering of templates.
module("Integration | Helper | raw", function (hooks) {
  setupRenderingTest(hooks);

  hooks.afterEach(() => {
    removeRawTemplate("raw-test");
  });

  test("can render a template", async function (assert) {
    addRawTemplate("raw-test", (params) => `raw test ${params.someArg}`);

    await render(<template>
      <span>{{raw "raw-test" someArg="foo"}}</span>
    </template>);

    assert.dom(`span`).hasText("raw test foo");
  });

  test("can render glimmer inside", async function (assert) {
    let willDestroyCalled = false;

    class MyComponent extends Component {
      <template>
        Hello from glimmer {{@data.someArg}}
      </template>

      willDestroy() {
        willDestroyCalled = true;
      }
    }

    addRawTemplate("raw-test", (params) =>
      rawRenderGlimmer(this, "div", MyComponent, { someArg: params.someArg })
    );

    class TestState {
      @tracked showRawTemplate = true;
    }

    const testState = new TestState();

    const renderGlimmerService = getOwner(this).lookup(
      "service:render-glimmer"
    );

    await render(<template>
      {{! RenderGlimmerContainer is normally rendered by application.hbs
          but this is not an acceptance test so we gotta include it manually }}
      <RenderGlimmerContainer />
      <span>
        {{#if testState.showRawTemplate}}
          {{raw "raw-test" someArg="foo"}}
        {{/if}}
      </span>
    </template>);

    assert.dom(`span`).hasText("Hello from glimmer foo");
    assert.strictEqual(
      renderGlimmerService._registrations.size,
      1,
      "renderGlimmer service has one registration"
    );

    testState.showRawTemplate = false;
    await settled();

    assert.dom(`span`).hasText("");
    assert.strictEqual(
      renderGlimmerService._registrations.size,
      0,
      "renderGlimmer service has no registrations"
    );

    assert.true(willDestroyCalled, "component was cleaned up correctly");
  });
});
