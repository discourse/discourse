import { click, render, settled, waitFor } from "@ember/test-helpers";
import { module, test } from "qunit";
import Form from "discourse/components/form";
import { codeEditorView } from "discourse/tests/helpers/code-editor-helper";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import formKit from "discourse/tests/helpers/form-kit-helper";

module("Integration | Component | FormKit | Controls | Code", function (hooks) {
  setupRenderingTest(hooks);

  test("default", async function (assert) {
    let data = { foo: null };
    const mutateData = (x) => (data = x);

    await render(
      <template>
        <Form @data={{data}} @onSubmit={{mutateData}} as |form|>
          <form.Field @name="foo" @title="Foo" @type="code" as |field|>
            <field.Control style="width: 200px" @height={{100}} />
          </form.Field>
        </Form>
      </template>
    );

    assert.deepEqual(data, { foo: null });
    assert.form().field("foo").hasValue("");

    await formKit().field("foo").fillIn("bar");
    await formKit().submit();

    assert.deepEqual(data, { foo: "bar" });
    assert.form().field("foo").hasValue("bar");
  });

  test("follows values set from outside", async function (assert) {
    let formApi;
    const data = { foo: "original" };
    const registerApi = (api) => (formApi = api);

    await render(
      <template>
        <Form @data={{data}} @onRegisterApi={{registerApi}} as |form|>
          <form.Field @name="foo" @title="Foo" @type="code" as |field|>
            <field.Control />
          </form.Field>
        </Form>
      </template>
    );
    await waitFor(".cm-content");

    await formApi.set("foo", "replaced");
    await settled();
    assert.dom(".cm-content").hasText("replaced");

    codeEditorView().dispatch({ changes: { from: 0, insert: "re" } });
    assert.strictEqual(formApi.get("foo"), "rereplaced");

    await formApi.reset();
    await settled();
    assert.dom(".cm-content").hasText("original");
  });

  test("is named and focused by its label", async function (assert) {
    await render(
      <template>
        <Form as |form|>
          <form.Field @name="foo" @title="Foo" @type="code" as |field|>
            <field.Control />
          </form.Field>
        </Form>
      </template>
    );
    await waitFor(".cm-content");

    const label = document.querySelector(".form-kit__container-title");
    assert.dom(".cm-content").hasAttribute("aria-labelledby", label.id);

    await click(label);
    assert.true(codeEditorView().hasFocus);
  });

  test("isn't named by a hidden title", async function (assert) {
    await render(
      <template>
        <Form as |form|>
          <form.Field
            @name="foo"
            @showTitle={{false}}
            @title="Foo"
            @type="code"
            as |field|
          >
            <field.Control />
          </form.Field>
        </Form>
      </template>
    );
    await waitFor(".cm-content");

    assert.dom(".cm-content").doesNotHaveAttribute("aria-labelledby");
  });

  test("@height", async function (assert) {
    await render(
      <template>
        <Form as |form|>
          <form.Field @name="foo" @title="Foo" @type="code" as |field|>
            <field.Control @height={{100}} />
          </form.Field>
        </Form>
      </template>
    );

    assert.strictEqual(
      document.querySelector(".form-kit__control-code").style.height,
      "100px"
    );
  });

  test("@lang", async function (assert) {
    const sqlData = { foo: "SELECT 1" };

    await render(
      <template>
        <Form @data={{sqlData}} as |form|>
          <form.Field @name="foo" @title="Foo" @type="code" as |field|>
            <field.Control @lang="sql" />
          </form.Field>
        </Form>
      </template>
    );

    await waitFor(".form-kit__control-code .cm-content span[class]");

    assert.true(
      [
        ...document.querySelectorAll(
          ".form-kit__control-code .cm-content span"
        ),
      ].some((span) => span.textContent.trim() === "SELECT"),
      "the language shortcut highlights the document"
    );
  });

  test("when disabled", async function (assert) {
    await render(
      <template>
        <Form as |form|>
          <form.Field
            @disabled={{true}}
            @name="foo"
            @title="Foo"
            @type="code"
            as |field|
          >
            <field.Control />
          </form.Field>
        </Form>
      </template>
    );

    await waitFor(".cm-content");

    assert.true(codeEditorView().state.readOnly);
  });
});
