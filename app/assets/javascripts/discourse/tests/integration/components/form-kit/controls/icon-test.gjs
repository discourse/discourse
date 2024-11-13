import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import Form from "discourse/components/form";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import formKit from "discourse/tests/helpers/form-kit-helper";

module("Integration | Component | FormKit | Controls | Icon", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    pretender.get("/svg-sprite/picker-search", () =>
      response(200, [{ id: "pencil", name: "pencil" }])
    );
  });

  test("default", async function (assert) {
    let data = { foo: null };
    const mutateData = (x) => (data = x);

    await render(<template>
      <Form @onSubmit={{mutateData}} @data={{data}} as |form|>
        <form.Field @name="foo" @title="Foo" as |field|>
          <field.Icon />
        </form.Field>
      </Form>
    </template>);

    await formKit().field("foo").select("pencil");
    await formKit().submit();

    assert.deepEqual(data.foo, "pencil");
    assert.form().field("foo").hasValue("pencil");
  });

  test("when disabled", async function (assert) {
    await render(<template>
      <Form as |form|>
        <form.Field @name="foo" @title="Foo" @disabled={{true}} as |field|>
          <field.Icon />
        </form.Field>
      </Form>
    </template>);

    assert.dom(".form-kit__control-icon.is-disabled").exists();
  });
});
