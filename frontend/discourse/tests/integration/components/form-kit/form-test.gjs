import { array, fn, hash } from "@ember/helper";
import { click, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import Form from "discourse/components/form";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import formKit from "discourse/tests/helpers/form-kit-helper";
import { query } from "discourse/tests/helpers/qunit-helpers";

module("Integration | Component | FormKit | Form", function (hooks) {
  setupRenderingTest(hooks);

  test("@onSubmit", async function (assert) {
    const onSubmit = (data) => {
      assert.deepEqual(data.foo, 1);
    };

    await render(
      <template><Form @data={{hash foo=1}} @onSubmit={{onSubmit}} /></template>
    );

    await formKit().submit();
  });

  test("addItemToCollection", async function (assert) {
    await render(
      <template>
        <Form @data={{hash foo=(array (hash bar=1) (hash bar=2))}} as |form|>
          <form.Button
            @action={{fn form.addItemToCollection "foo" (hash bar=3)}}
          >Add</form.Button>

          <form.Collection @name="foo" as |collection|>
            <collection.Field @type="input" @name="bar" @title="Bar" as |field|>
              <field.Control />
            </collection.Field>
          </form.Collection>
        </Form>
      </template>
    );

    await click("button");

    assert.form().field("foo.0.bar").hasValue("1");
    assert.form().field("foo.1.bar").hasValue("2");
    assert.form().field("foo.2.bar").hasValue("3");
  });

  test("@validate", async function (assert) {
    const validate = async (data, { addError }) => {
      assert.deepEqual(data.foo, 1);
      assert.deepEqual(data.bar, 2);
      addError("foo", { title: "Foo", message: "incorrect type" });
      addError("foo", { title: "Foo", message: "required" });
      addError("bar", { title: "Bar", message: "error" });
    };

    await render(
      <template>
        <Form @data={{hash foo=1 bar=2}} @validate={{validate}} as |form|>
          <form.Field @type="input" @name="foo" @title="Foo" />
          <form.Field @type="input" @name="bar" @title="Bar" />
        </Form>
      </template>
    );

    await formKit().submit();

    assert.form().hasErrors({
      foo: "incorrect type, required",
      bar: "error",
    });
  });

  test("@validateOn", async function (assert) {
    const data = { foo: "test" };

    await render(
      <template>
        <Form @data={{data}} as |form|>
          <form.Field
            @type="input"
            @name="foo"
            @title="Foo"
            @validation="required"
            as |field|
          >
            <field.Control />
          </form.Field>
          <form.Field
            @type="input"
            @name="bar"
            @title="Bar"
            @validation="required"
            as |field|
          >
            <field.Control />
          </form.Field>
          <form.Submit />
        </Form>
      </template>
    );

    await formKit().field("foo").fillIn("");

    assert.form().field("foo").hasNoErrors();

    await formKit().submit();

    assert.form().field("foo").hasError("Required");
    assert.form().field("bar").hasError("Required");
    assert.form().hasErrors({
      foo: "Required",
      bar: "Required",
    });

    await formKit().field("foo").fillIn("t");

    assert.form().field("foo").hasNoErrors();
    assert.form().field("bar").hasError("Required");
    assert.form().hasErrors({
      bar: "Required",
    });
  });

  test("@onRegisterApi", async function (assert) {
    let formApi;
    let model = { foo: 1 };

    const registerApi = (api) => {
      formApi = api;
    };

    const submit = (x) => {
      model = x;
      assert.deepEqual(model.foo, 1);
    };

    await render(
      <template>
        <Form
          @data={{model}}
          @onSubmit={{submit}}
          @onRegisterApi={{registerApi}}
          as |form data|
        >
          <div class="bar">{{data.bar}}</div>
        </Form>
      </template>
    );

    await formApi.set("bar", 2);
    assert.strictEqual(
      formApi.get("bar"),
      2,
      "get() returns the current value"
    );
    await formApi.submit();

    assert.dom(".bar").hasText("2");

    await formApi.set("bar", 1);
    assert.strictEqual(
      formApi.get("bar"),
      1,
      "get() returns the updated value"
    );
    await formApi.reset();
    await formApi.submit();

    assert.dom(".bar").hasText("2");
    assert.strictEqual(
      formApi.get("bar"),
      2,
      "get() returns the correct value after reset"
    );

    formApi.addError("bar", { title: "Bar", message: "error_foo" });
    // assert on the next tick
    setTimeout(() => {
      assert.form().hasErrors({ bar: "error_foo" });
    }, 0);
  });

  test("@onRegisterApi - commitField", async function (assert) {
    let formApi;
    const model = { foo: "a", bar: "b" };
    const registerApi = (api) => (formApi = api);

    await render(
      <template>
        <Form @data={{model}} @onRegisterApi={{registerApi}} as |form data|>
          <div class="foo">{{data.foo}}</div>
          <div class="bar">{{data.bar}}</div>
        </Form>
      </template>
    );

    await formApi.set("foo", "a2");
    await formApi.set("bar", "b2");
    formApi.commitField("foo");

    assert.true(formApi.isDirty, "still dirty because 'bar' is uncommitted");

    await formApi.reset();

    assert
      .dom(".foo")
      .hasText("a2", "'foo' keeps its committed value after reset");
    assert.dom(".bar").hasText("b", "'bar' reverts to original after reset");
  });

  test("@onRegisterApi - isDirty", async function (assert) {
    let formApi;
    const model = { foo: 1 };
    const registerApi = (api) => (formApi = api);

    await render(
      <template>
        <Form @data={{model}} @onRegisterApi={{registerApi}} as |form|>
          <form.Field @type="input" @name="foo" @title="Foo" as |field|>
            <field.Control />
          </form.Field>
        </Form>
      </template>
    );

    assert.false(formApi.isDirty, "form is not dirty initially");

    await formKit().field("foo").fillIn("2");

    assert.true(formApi.isDirty, "form is dirty after a change");

    await formApi.reset();

    assert.false(formApi.isDirty, "form is not dirty after reset");
  });

  test("@data", async function (assert) {
    await render(
      <template>
        <Form @data={{hash foo=1}} as |form data|>
          <div class="foo">{{data.foo}}</div>
        </Form>
      </template>
    );

    assert.dom(".foo").hasText("1");
  });

  test("@onReset", async function (assert) {
    const done = assert.async();
    const onReset = async () => {
      assert
        .form()
        .field("bar")
        .hasValue("1", "it resets the data to its initial state");
      done();
    };

    await render(
      <template>
        <Form @data={{hash bar=1}} @onReset={{onReset}} as |form|>
          <form.Field
            @type="input"
            @title="Foo"
            @name="foo"
            @validation="required"
            as |field|
          >
            <field.Control />
          </form.Field>
          <form.Field @type="input" @title="Bar" @name="bar" as |field|>
            <field.Control />
          </form.Field>
          <form.Button class="set-bar" @action={{fn form.set "bar" 2}} />
        </Form>
      </template>
    );

    await click(".set-bar");
    await formKit().field("foo").fillIn("");

    await formKit().submit();

    assert.form().field("bar").hasValue("2");
    assert.form().field("foo").hasError("Required");

    await formKit().reset();

    assert.form().field("foo").hasNoErrors("it resets the errors");
  });

  test("immutable by default", async function (assert) {
    const data = { foo: 1 };

    await render(
      <template>
        <Form @data={{data}} as |form|>
          <form.Field @type="input" @name="foo" @title="Foo" as |field|>
            <field.Control />
          </form.Field>
          <form.Button class="set-foo" @action={{fn form.set "foo" 2}} />
        </Form>
      </template>
    );

    await click(".set-foo");

    assert.deepEqual(data.foo, 1);
  });

  test("yielded set", async function (assert) {
    await render(
      <template>
        <Form @data={{hash foo=1}} as |form data|>
          <div class="foo">{{data.foo}}</div>
          <form.Button class="test" @action={{fn form.set "foo" 2}} />
        </Form>
      </template>
    );

    await click(".test");

    assert.dom(".foo").hasText("2");
  });

  test("yielded commitField", async function (assert) {
    let formApi;
    const registerApi = (api) => (formApi = api);

    await render(
      <template>
        <Form
          @data={{hash foo=1 bar=2}}
          @onRegisterApi={{registerApi}}
          as |form data|
        >
          <div class="foo">{{data.foo}}</div>
          <div class="bar">{{data.bar}}</div>
          <form.Button class="set-foo" @action={{fn form.set "foo" 10}} />
          <form.Button
            class="commit-foo"
            @action={{fn form.commitField "foo"}}
          />
        </Form>
      </template>
    );

    await click(".set-foo");
    assert.dom(".foo").hasText("10");

    await click(".commit-foo");

    await formApi.reset();

    assert.dom(".foo").hasText("10", "committed field survives reset");
    assert.dom(".bar").hasText("2", "uncommitted field keeps original value");
  });

  test("yielded setProperties", async function (assert) {
    await render(
      <template>
        <Form @data={{hash foo=1 bar=1}} as |form data|>
          <div class="foo">{{data.foo}}</div>
          <div class="bar">{{data.bar}}</div>
          <form.Button
            class="test"
            @action={{fn form.setProperties (hash foo=2 bar=2)}}
          />
        </Form>
      </template>
    );

    await click(".test");

    assert.dom(".foo").hasText("2");
    assert.dom(".bar").hasText("2");
  });

  test("reset virtual errors", async function (assert) {
    let validatedOnce = false;
    const validate = async (data, { removeError, addError }) => {
      if (!validatedOnce) {
        addError("foo", { title: "Foo", message: "error" });

        validatedOnce = true;
      } else {
        removeError("foo");
      }
    };

    await render(
      <template>
        <Form @validate={{validate}} as |form|>
          <form.Submit />
        </Form>
      </template>
    );

    await formKit().submit();

    assert.form().hasErrors({ foo: "error" });

    await formKit().submit();

    assert.form().hasNoErrors();
  });

  test("destroying field", async function (assert) {
    await render(
      <template>
        <Form @data={{hash visible=true}} as |form data|>
          {{#if data.visible}}
            <form.Field
              @type="input"
              @title="Foo"
              @name="foo"
              @validation="required"
              as |field|
            >
              <field.Control />
            </form.Field>
          {{/if}}

          <form.Button
            class="test"
            @action={{fn form.setProperties (hash visible=false)}}
          />
        </Form>
      </template>
    );

    await formKit().submit();

    assert.form().hasErrors({ foo: "Required" });

    await click(".test");

    assert.form().hasNoErrors("remove the errors associated with this field");
  });

  test("scroll to top on error", async function (assert) {
    const validate = async (data, { addError }) => {
      addError("bar", { title: "Foo", message: "error" });
    };

    await render(
      <template>
        <Form @validate={{validate}} as |form|>
          <div style="height: 1000px;"></div>
          <form.Submit />
        </Form>
      </template>
    );

    query(".form-kit__button").scrollIntoView();

    await formKit().submit();

    assert.strictEqual(
      document.querySelector("#ember-testing-container").scrollTop,
      0
    );
  });

  test("clicking error link focuses the field input", async function (assert) {
    await render(
      <template>
        <Form as |form|>
          <form.Field
            @type="input"
            @name="foo"
            @title="Foo"
            @validation="required"
            as |field|
          >
            <field.Control />
          </form.Field>
          <form.Submit />
        </Form>
      </template>
    );

    await formKit().submit();

    await click(".form-kit__errors-summary-list a");

    assert.dom(document.activeElement).hasClass("form-kit__control-input");
  });

  test("error link has anchor href for fields without focusable elements", async function (assert) {
    const validate = async (data, { addError }) => {
      addError("foo", { title: "Foo", message: "error" });
    };

    await render(
      <template>
        <Form @validate={{validate}} as |form|>
          <form.Field @name="foo" @type="custom" @title="Foo" as |field|>
            <field.Control>
              <div class="not-focusable">Custom content</div>
            </field.Control>
          </form.Field>
          <form.Submit />
        </Form>
      </template>
    );

    await formKit().submit();

    assert
      .dom(".form-kit__errors-summary-list a")
      .hasAttribute("href", "#control-foo");
  });
});
