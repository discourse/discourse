import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { getOwner } from "@ember/owner";
import { render, settled } from "@ember/test-helpers";
import { module, test } from "qunit";
import RenderGlimmerContainer from "discourse/components/render-glimmer-container";
import raw from "discourse/helpers/raw";
import { compile } from "discourse/lib/raw-handlebars";
import { RUNTIME_OPTIONS } from "discourse/lib/raw-handlebars-helpers";
import rawRenderGlimmer from "discourse/lib/raw-render-glimmer";
import { addRawTemplate, removeRawTemplate } from "discourse/lib/raw-templates";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

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
        super.willDestroy(...arguments);
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

  test("does not add extra whitespace", async function (assert) {
    const SimpleTemplate = <template>baz</template>;

    addRawTemplate("raw-test", () =>
      rawRenderGlimmer(this, "span.bar", SimpleTemplate)
    );

    await render(<template>
      <RenderGlimmerContainer />
      {{raw "raw-test"}}
    </template>);

    assert.dom("span.bar").hasText(/^baz$/);
  });

  test("#each helper preserves the outer context", async function (assert) {
    const template = `
      {{#each items as |item|}}
        {{string}} {{item}}
      {{/each}}
    `;
    addRawTemplate("raw-test", compile(template));

    const items = [1, 2];
    await render(<template>
      <span>{{raw "raw-test" string="foo" items=items}}</span>
    </template>);

    assert.dom("span").hasText("foo 1 foo 2");
  });

  test("#each helper handles getters", async function (assert) {
    const template = `
      {{#each items as |item|}}
        {{string}} {{item}}
      {{/each}}
    `;
    const compiledTemplate = compile(template);

    class Test {
      items = [1, 2];

      get string() {
        return "foo";
      }
    }

    const object = new Test();

    const output = compiledTemplate(object, RUNTIME_OPTIONS);
    assert.true(/\s*foo 1\s*foo 2\s*/.test(output));
  });
});
