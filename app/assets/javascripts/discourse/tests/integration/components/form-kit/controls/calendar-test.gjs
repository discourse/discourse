import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import Form from "discourse/components/form";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import formKit from "discourse/tests/helpers/form-kit-helper";
import { i18n } from "discourse-i18n";

module(
  "Integration | Component | FormKit | Controls | Calendar",
  function (hooks) {
    setupRenderingTest(hooks);

    test("default", async function (assert) {
      let data = { foo: null };
      const mutateData = (x) => (data = x);

      await render(
        <template>
          <Form @onSubmit={{mutateData}} @data={{data}} as |form|>
            <form.Field @name="foo" @title="Foo" as |field|>
              <field.Calendar />
            </form.Field>
          </Form>
        </template>
      );

      await formKit().field("foo").setDay(22);
      await formKit().field("foo").setTime("11:12");
      await formKit().submit();

      assert.deepEqual(data, {
        foo: new Date(`${moment().format("YYYY-MM")}-22T11:12:00`),
      });
    });

    test("@includeTime", async function (assert) {
      await render(
        <template>
          <Form as |form|>
            <form.Field @name="foo" @title="Foo" as |field|>
              <field.Calendar />
            </form.Field>
          </Form>
        </template>
      );

      assert.dom(".form-kit__control-time").exists();

      await render(
        <template>
          <Form as |form|>
            <form.Field @name="foo" @title="Foo" as |field|>
              <field.Calendar @includeTime={{false}} />
            </form.Field>
          </Form>
        </template>
      );

      assert.dom(".form-kit__control-time").doesNotExist();
    });

    test("@expandedDatePickerOnDesktop", async function (assert) {
      await render(
        <template>
          <Form as |form|>
            <form.Field @name="foo" @title="Foo" as |field|>
              <field.Calendar />
            </form.Field>
          </Form>
        </template>
      );

      assert.dom(".date-picker-container").exists();
      assert.dom(".form-kit__control-date").doesNotExist();

      await render(
        <template>
          <Form as |form|>
            <form.Field @name="foo" @title="Foo" as |field|>
              <field.Calendar @expandedDatePickerOnDesktop={{false}} />
            </form.Field>
          </Form>
        </template>
      );

      assert.dom(".date-picker-container").doesNotExist();
      assert.dom(".form-kit__control-date").exists();
    });

    test("dateBeforeOrEqual validation", async function (assert) {
      let data = { foo: moment().toDate() };
      const mutateData = (x) => (data = x);
      const date = moment().subtract(2, "days");
      const validation = `dateBeforeOrEqual:${date.format("YYYY-MM-DD")}`;

      await render(
        <template>
          <Form @onSubmit={{mutateData}} @data={{data}} as |form|>
            <form.Field
              @validation={{validation}}
              @name="foo"
              @title="Foo"
              as |field|
            >
              <field.Calendar />
            </form.Field>
          </Form>
        </template>
      );

      await formKit().submit();

      assert
        .form()
        .field("foo")
        .hasError(
          i18n("form_kit.errors.date_before_or_equal", {
            date: date.format("LL"),
          })
        );
    });

    test("dateAfterOrEqual validation", async function (assert) {
      let data = { foo: moment().toDate() };
      const mutateData = (x) => (data = x);
      const date = moment().add(2, "days");
      const validation = `dateAfterOrEqual:${date.format("YYYY-MM-DD")}`;

      await render(
        <template>
          <Form @onSubmit={{mutateData}} @data={{data}} as |form|>
            <form.Field
              @validation={{validation}}
              @name="foo"
              @title="Foo"
              as |field|
            >
              <field.Calendar />
            </form.Field>
          </Form>
        </template>
      );

      await formKit().submit();

      assert
        .form()
        .field("foo")
        .hasError(
          i18n("form_kit.errors.date_after_or_equal", {
            date: date.format("LL"),
          })
        );
    });

    test("when disabled", async function (assert) {
      await render(
        <template>
          <Form as |form|>
            <form.Field @name="foo" @title="Foo" @disabled={{true}} as |field|>
              <field.Calendar />
            </form.Field>
          </Form>
        </template>
      );

      assert.dom(".pika-button.pika-day").hasStyle({
        "pointer-events": "none",
      });
      assert.dom(".form-kit__control-time").isDisabled();
    });
  }
);
