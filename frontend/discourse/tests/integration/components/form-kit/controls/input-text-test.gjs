import {
  fillIn as fillInput,
  focus,
  render,
  rerender,
  resetOnerror,
  setupOnerror,
} from "@ember/test-helpers";
import { module, test } from "qunit";
import Form from "discourse/components/form";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import formKit from "discourse/tests/helpers/form-kit-helper";
import DNativeSelect from "discourse/ui-kit/d-native-select";

module(
  "Integration | Component | FormKit | Controls | Input | Text",
  function (hooks) {
    setupRenderingTest(hooks);

    hooks.afterEach(() => resetOnerror());

    test("default", async function (assert) {
      let data = { foo: "" };
      const mutateData = (x) => (data = x);

      await render(
        <template>
          <Form @onSubmit={{mutateData}} @data={{data}} as |form|>
            <form.Field @type="input" @name="foo" @title="Foo" as |field|>
              <field.Control />
            </form.Field>
          </Form>
        </template>
      );

      assert.form().field("foo").hasValue("");

      await formKit().field("foo").fillIn("bar");

      assert.form().field("foo").hasValue("bar");

      await formKit().submit();

      assert.deepEqual(data.foo, "bar");
    });

    test("when disabled", async function (assert) {
      await render(
        <template>
          <Form as |form|>
            <form.Field
              @type="input"
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

      assert.dom(".form-kit__control-input").hasAttribute("disabled");
    });

    test("when emptied", async function (assert) {
      let data = { foo: "xxx" };
      const mutateData = (x) => (data = x);

      await render(
        <template>
          <Form @data={{data}} @onSubmit={{mutateData}} as |form|>
            <form.Field @type="input" @name="foo" @title="Foo" as |field|>
              <field.Control />
            </form.Field>
          </Form>
        </template>
      );

      await formKit().field("foo").fillIn("");
      await formKit().submit();

      assert.deepEqual(data.foo, null, "it nullifies the value");
    });

    test("@before and @after", async function (assert) {
      await render(
        <template>
          <Form as |form|>
            <form.Field @type="input" @name="foo" @title="Foo" as |field|>
              <field.Control @before="https://" @after=".com" />
            </form.Field>
          </Form>
        </template>
      );

      assert.dom(".form-kit__before-input").hasText("https://");
      assert.dom(".form-kit__after-input").hasText(".com");
      assert.dom(".form-kit__control-input").hasClass("has-prefix");
      assert.dom(".form-kit__control-input").hasClass("has-suffix");
    });

    test("named addons render independently alongside text arguments", async function (assert) {
      await render(
        <template>
          <Form as |form|>
            <form.Field @type="input" @name="prefix" @title="Prefix" as |field|>
              <field.Control @after=".com">
                <:before><strong>https://</strong></:before>
              </field.Control>
            </form.Field>
            <form.Field @type="input" @name="suffix" @title="Suffix" as |field|>
              <field.Control @before="https://">
                <:after><strong>.com</strong></:after>
              </field.Control>
            </form.Field>
            <form.Field @type="input" @name="both" @title="Both" as |field|>
              <field.Control>
                <:before><strong>Before</strong></:before>
                <:after><strong>After</strong></:after>
              </field.Control>
            </form.Field>
          </Form>
        </template>
      );

      assert
        .dom(".form-kit__before-input strong")
        .exists({ count: 2 }, "prefix blocks render markup");
      assert
        .dom(".form-kit__after-input strong")
        .exists({ count: 2 }, "suffix blocks render markup");
      assert
        .dom("input.has-prefix.has-suffix")
        .exists({ count: 3 }, "both forms participate in joined input styling");
    });

    test("named addons support interactive controls and explicit disabled bindings", async function (assert) {
      this.disabled = false;
      this.unit = "px";
      const changeUnit = (value) => this.set("unit", value);

      await render(
        <template>
          <Form as |form|>
            <form.Field
              @type="input-number"
              @name="size"
              @title="Size"
              @disabled={{this.disabled}}
              as |field|
            >
              <field.Control>
                <:after>
                  <DNativeSelect
                    aria-label="Unit"
                    disabled={{field.disabled}}
                    @includeNone={{false}}
                    @value={{this.unit}}
                    @onChange={{changeUnit}}
                    as |select|
                  >
                    <select.Option @value="px">px</select.Option>
                    <select.Option @value="%">%</select.Option>
                  </DNativeSelect>
                </:after>
              </field.Control>
            </form.Field>
          </Form>
        </template>
      );

      assert
        .dom("select")
        .hasAttribute(
          "aria-label",
          "Unit",
          "addon has its own accessible name"
        );
      await focus("select");
      assert.dom("select").isFocused("addon is independently focusable");
      await fillInput("select", "%");
      assert.strictEqual(this.unit, "%", "addon remains interactive");
      await fillInput("input", "25");
      assert.form().field("size").hasValue("25");
      this.set("disabled", true);
      await rerender();
      assert.dom("input").isDisabled("input follows field state");
      assert.dom("select").isDisabled("consumer can bind addon to field state");
    });

    for (const direction of ["ltr", "rtl"]) {
      test(`named addons align in a narrow ${direction} field`, async function (assert) {
        await render(
          <template>
            <div dir={{direction}} style="width: 160px;">
              <Form as |form|>
                <form.Field
                  @type="input-number"
                  @name="size"
                  @title="Size"
                  as |field|
                >
                  <field.Control @before="$">
                    <:after>
                      <DNativeSelect
                        aria-label="Unit"
                        @includeNone={{false}}
                        as |select|
                      >
                        <select.Option @value="px">px</select.Option>
                      </DNativeSelect>
                    </:after>
                  </field.Control>
                </form.Field>
              </Form>
            </div>
          </template>
        );

        const wrapper = this.element.querySelector(
          ".form-kit__control-input-wrapper"
        );
        const input = wrapper.querySelector("input");
        const select = wrapper.querySelector("select");
        const prefix = wrapper.querySelector(".form-kit__before-input");
        const suffix = wrapper.querySelector(".form-kit__after-input");
        const bounds = wrapper.getBoundingClientRect();
        const inputBounds = input.getBoundingClientRect();
        const selectBounds = select.getBoundingClientRect();
        assert.true(
          inputBounds.width > 0,
          "numeric input retains usable space"
        );
        for (const element of [prefix, input, suffix, select]) {
          const rect = element.getBoundingClientRect();
          assert.true(
            rect.left >= bounds.left - 1,
            "part stays within the left edge"
          );
          assert.true(
            rect.right <= bounds.right + 1,
            "part stays within the right edge"
          );
          assert.true(Math.abs(rect.top - inputBounds.top) < 1, "tops align");
          assert.true(
            Math.abs(rect.height - inputBounds.height) < 1,
            "heights match"
          );
        }
        const seam =
          direction === "ltr"
            ? selectBounds.left - inputBounds.right
            : inputBounds.left - selectBounds.right;
        assert.true(
          Math.abs(seam) <= 1,
          "input and selector share one border seam"
        );
        assert.strictEqual(
          getComputedStyle(suffix).paddingInlineStart,
          "0px",
          "rich addon has no text-addon padding"
        );
        assert.strictEqual(
          getComputedStyle(select).borderStartStartRadius,
          "0px",
          "selector has square joined corners in both directions"
        );
      });
    }

    for (const side of ["before", "after"]) {
      for (const value of ["text", "", null]) {
        test(`named addons reject @${side} and its block, including ${JSON.stringify(value)}`, async function (assert) {
          const errors = [];
          const before = side === "before";
          setupOnerror((error) => {
            errors.push(error.message);
          });

          await render(
            <template>
              <Form as |form|>
                <form.Field @type="input" @name="foo" @title="Foo" as |field|>
                  {{#if before}}
                    <field.Control @before={{value}}><:before
                      >Prefix</:before></field.Control>
                  {{else}}
                    <field.Control @after={{value}}><:after
                      >Suffix</:after></field.Control>
                  {{/if}}
                </form.Field>
              </Form>
            </template>
          );
          assert.deepEqual(
            errors,
            [
              `Assertion Failed: Do not pass @${side} and a named ${side} block to the same input.`,
            ],
            "conflict identifies the side"
          );
        });
      }
    }

    test("named addons validate arguments on rerender", async function (assert) {
      this.after = undefined;
      await render(
        <template>
          <Form as |form|>
            <form.Field @type="input" @name="foo" @title="Foo" as |field|>
              <field.Control @after={{this.after}}><:after
                >Suffix</:after></field.Control>
            </form.Field>
          </Form>
        </template>
      );

      assert
        .dom(".form-kit__after-input")
        .hasText("Suffix", "undefined argument does not conflict");
      const errors = [];
      setupOnerror((error) => {
        errors.push(error.message);
      });
      this.set("after", "");
      await rerender();
      assert.deepEqual(
        errors,
        [
          "Assertion Failed: Do not pass @after and a named after block to the same input.",
        ],
        "later conflicts are rejected"
      );
    });

    test("disabled, name, and placeholder attributes", async function (assert) {
      await render(
        <template>
          <Form as |form|>
            <form.Field
              @type="input"
              @name="foo"
              @title="Foo"
              @disabled={{true}}
              @placeholder="Enter text"
              as |field|
            >
              <field.Control />
            </form.Field>
          </Form>
        </template>
      );

      assert.dom(".form-kit__control-input").hasAttribute("disabled");
      assert.dom(".form-kit__control-input").hasAttribute("name", "foo");
      assert
        .dom(".form-kit__control-input")
        .hasAttribute("placeholder", "Enter text");
    });
  }
);
