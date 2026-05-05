import { hash } from "@ember/helper";
import { render, settled } from "@ember/test-helpers";
import { module, test } from "qunit";
import Form from "discourse/components/form";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import formKit from "discourse/tests/helpers/form-kit-helper";

async function withTextareaScrollHeight(getScrollHeight, callback) {
  const descriptor = Object.getOwnPropertyDescriptor(
    HTMLTextAreaElement.prototype,
    "scrollHeight"
  );

  Object.defineProperty(HTMLTextAreaElement.prototype, "scrollHeight", {
    configurable: true,
    get() {
      return getScrollHeight(this);
    },
  });

  try {
    await callback();
  } finally {
    if (descriptor) {
      Object.defineProperty(
        HTMLTextAreaElement.prototype,
        "scrollHeight",
        descriptor
      );
    } else {
      delete HTMLTextAreaElement.prototype.scrollHeight;
    }
  }
}

function numericStyleValue(style, property) {
  return Number.parseFloat(style[property]) || 0;
}

function expectedTextareaHeight(textarea) {
  const style = getComputedStyle(textarea);
  let height = textarea.scrollHeight;

  if (style.boxSizing === "border-box") {
    height +=
      numericStyleValue(style, "borderTopWidth") +
      numericStyleValue(style, "borderBottomWidth");
  }

  return `${Math.ceil(height)}px`;
}

async function waitForTextareaResize() {
  await new Promise((resolve) => requestAnimationFrame(resolve));
}

module(
  "Integration | Component | FormKit | Controls | Textarea",
  function (hooks) {
    setupRenderingTest(hooks);

    test("default", async function (assert) {
      let data = { foo: null };
      const mutateData = (x) => (data = x);

      await render(
        <template>
          <Form @onSubmit={{mutateData}} @data={{data}} as |form|>
            <form.Field @type="textarea" @name="foo" @title="Foo" as |field|>
              <field.Control />
            </form.Field>
          </Form>
        </template>
      );

      assert.deepEqual(data, { foo: null });
      assert.form().field("foo").hasValue("");

      await formKit().field("foo").fillIn("bar");

      assert.form().field("foo").hasValue("bar");

      await formKit().submit();

      assert.deepEqual(data, { foo: "bar" });
    });

    test("when disabled", async function (assert) {
      await render(
        <template>
          <Form as |form|>
            <form.Field
              @type="textarea"
              @name="foo"
              @title="Foo"
              @disabled={{true}}
              as |field|
            >
              <field.Control />
            </form.Field>
          </Form>
        </template>
      );

      assert.dom(".form-kit__control-textarea").hasAttribute("disabled");
    });

    test("dynamically updates textarea value", async function (assert) {
      let formApi;
      const registerApi = (api) => (formApi = api);

      await render(
        <template>
          <Form
            @data={{hash content="initial value"}}
            @onRegisterApi={{registerApi}}
            as |form|
          >
            <form.Field
              @type="textarea"
              @name="content"
              @title="Content"
              as |field|
            >
              <field.Control />
            </form.Field>
          </Form>
        </template>
      );

      assert.form().field("content").hasValue("initial value");
      assert.dom(".form-kit__control-textarea").hasValue("initial value");

      formApi.set("content", "updated value");
      await settled();

      assert.form().field("content").hasValue("updated value");
      assert.dom(".form-kit__control-textarea").hasValue("updated value");

      formApi.set("content", "");
      await settled();

      assert.form().field("content").hasValue("");
      assert.dom(".form-kit__control-textarea").hasValue("");

      formApi.set("content", "final value");
      await settled();

      assert.form().field("content").hasValue("final value");
      assert.dom(".form-kit__control-textarea").hasValue("final value");
    });

    test("Ctrl/Cmd + Enter submits the form", async function (assert) {
      let data = { foo: null };
      const mutateData = (x) => (data = x);

      await render(
        <template>
          <Form @onSubmit={{mutateData}} as |form|>
            <form.Field @type="textarea" @name="foo" @title="Foo" as |field|>
              <field.Control />
            </form.Field>
          </Form>
        </template>
      );

      await formKit().field("foo").fillIn("bar");
      await formKit().field("foo").triggerEvent("keydown", {
        key: "Enter",
        ctrlKey: true,
      });
      await settled();

      assert.deepEqual(data, { foo: "bar" });
    });

    test("@height", async function (assert) {
      await render(
        <template>
          <Form as |form|>
            <form.Field @type="textarea" @name="foo" @title="Foo" as |field|>
              <field.Control @height={{42}} />
            </form.Field>
          </Form>
        </template>
      );

      assert
        .dom(".form-kit__control-textarea")
        .hasAttribute("style", "height: 42px");
    });

    test("@autoResize sizes on insert and input", async function (assert) {
      await withTextareaScrollHeight(
        (textarea) => (textarea.value.includes("long") ? 500 : 80),
        async () => {
          await render(
            <template>
              <Form @data={{hash content="short"}} as |form|>
                <form.Field
                  @type="textarea"
                  @name="content"
                  @title="Content"
                  as |field|
                >
                  <field.Control @autoResize={{true}} />
                </form.Field>
              </Form>
            </template>
          );

          const textarea = document.querySelector(
            ".form-kit__control-textarea"
          );
          await waitForTextareaResize();

          assert.strictEqual(
            textarea.style.height,
            expectedTextareaHeight(textarea)
          );

          await formKit().field("content").fillIn("long content");
          await waitForTextareaResize();

          assert.strictEqual(
            textarea.style.height,
            expectedTextareaHeight(textarea)
          );
        }
      );
    });

    test("@autoResize allows CSS-based sizing", async function (assert) {
      await withTextareaScrollHeight(
        (textarea) => (textarea.value.includes("long") ? 500 : 80),
        async () => {
          await render(
            <template>
              <Form @data={{hash content="long content"}} as |form|>
                <form.Field
                  @type="textarea"
                  @name="content"
                  @title="Content"
                  as |field|
                >
                  <field.Control
                    @autoResize={{true}}
                    style="min-height: 120px; max-height: 400px; overflow-y: auto"
                  />
                </form.Field>
              </Form>
            </template>
          );

          const textarea = document.querySelector(
            ".form-kit__control-textarea"
          );
          await waitForTextareaResize();
          const style = getComputedStyle(textarea);

          assert.strictEqual(
            textarea.style.height,
            expectedTextareaHeight(textarea)
          );
          assert.strictEqual(style.minHeight, "120px");
          assert.strictEqual(style.maxHeight, "400px");
          assert.strictEqual(style.overflowY, "auto");
        }
      );
    });

    test("@autoResize updates when the form value changes", async function (assert) {
      let formApi;
      const registerApi = (api) => (formApi = api);

      await withTextareaScrollHeight(
        (textarea) => (textarea.value.includes("long") ? 300 : 60),
        async () => {
          await render(
            <template>
              <Form
                @data={{hash content="short"}}
                @onRegisterApi={{registerApi}}
                as |form|
              >
                <form.Field
                  @type="textarea"
                  @name="content"
                  @title="Content"
                  as |field|
                >
                  <field.Control @autoResize={{true}} />
                </form.Field>
              </Form>
            </template>
          );

          const textarea = document.querySelector(
            ".form-kit__control-textarea"
          );
          await waitForTextareaResize();

          assert.strictEqual(
            textarea.style.height,
            expectedTextareaHeight(textarea)
          );

          formApi.set("content", "long content");
          await settled();
          await waitForTextareaResize();

          assert.strictEqual(
            textarea.style.height,
            expectedTextareaHeight(textarea)
          );
        }
      );
    });

    test("does not resize when @autoResize is not passed", async function (assert) {
      await render(
        <template>
          <Form @data={{hash content="some content"}} as |form|>
            <form.Field
              @type="textarea"
              @name="content"
              @title="Content"
              as |field|
            >
              <field.Control />
            </form.Field>
          </Form>
        </template>
      );

      const textarea = document.querySelector(".form-kit__control-textarea");
      await waitForTextareaResize();

      assert.strictEqual(textarea.style.height, "");
    });
  }
);
