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
      response(200, [{ id: "pencil-alt", name: "pencil-alt" }])
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

    await formKit().field("foo").select("pencil-alt");
    await formKit().submit();

    assert.deepEqual(data.foo, "pencil-alt");
    assert.form().field("foo").hasValue("pencil-alt");
  });
});
