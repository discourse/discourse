import { click, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import Form from "discourse/components/form";
import { withPluginApi } from "discourse/lib/plugin-api";
import Site from "discourse/models/site";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import dSelect from "discourse/tests/helpers/d-select-helper";
import formKit from "discourse/tests/helpers/form-kit-helper";
import selectKit from "discourse/tests/helpers/select-kit-helper";
import I18n, { i18n } from "discourse-i18n";

const CONTROL = ".form-kit__control-category-chooser";

/** Values of the mounted options of the open panel, in order. */
function optionValues() {
  return [...document.querySelectorAll("[role='option'][data-value]")].map(
    (option) => option.dataset.value
  );
}

/** The element carrying the combobox role, wherever the variant places it. */
function combobox() {
  return (
    document.querySelector(`${CONTROL} [role='combobox']`) ??
    document.querySelector(`${CONTROL}[role='combobox']`)
  );
}

/** The text the empty control offers, whichever variant renders it. */
function placeholderText() {
  return (
    dSelect(CONTROL)
      .element()
      .querySelector(".d-select__placeholder")
      ?.textContent.trim() ?? combobox().getAttribute("placeholder")
  );
}

/** The text of the elements an ARIA id-reference attribute points at. */
function referencedText(ids) {
  return (ids ?? "")
    .split(/\s+/)
    .map((id) => document.getElementById(id)?.textContent.trim() ?? "")
    .join(" ");
}

module(
  "Integration | Component | FormKit | Controls | CategoryChooser",
  function (hooks) {
    setupRenderingTest(hooks);

    test("stores the picked category's id", async function (assert) {
      let data = { foo: null };
      const submit = (x) => (data = x);

      await render(
        <template>
          <Form @data={{data}} @onSubmit={{submit}} as |form|>
            <form.Field
              @name="foo"
              @title="Foo"
              @type="category-chooser"
              as |field|
            >
              <field.Control />
            </form.Field>
          </Form>
        </template>
      );

      assert.dom(`${CONTROL}.select-kit`).exists("the legacy control");

      const chooser = selectKit(CONTROL);
      await chooser.expand();
      await chooser.selectRowByValue(1);
      await formKit().submit();

      assert.strictEqual(data.foo, 1);
    });

    test("@multiple stores ids", async function (assert) {
      let data = { foo: [2] };
      const submit = (x) => (data = x);

      await render(
        <template>
          <Form @data={{data}} @onSubmit={{submit}} as |form|>
            <form.Field
              @name="foo"
              @title="Foo"
              @type="category-chooser"
              as |field|
            >
              <field.Control @multiple={{true}} />
            </form.Field>
          </Form>
        </template>
      );

      const chooser = selectKit(CONTROL);
      await chooser.expand();
      await chooser.selectRowByValue(1);
      await formKit().submit();

      assert.deepEqual(data.foo, [2, 1]);
    });

    test("held ids the site has not loaded are kept when lazy", async function (assert) {
      Site.current().set("lazy_load_categories", true);
      pretender.get("/categories/find", () =>
        response({
          categories: [{ id: 9900, name: "Remote", slug: "remote" }],
        })
      );
      let data = { foo: [9900] };
      const submit = (x) => (data = x);

      await render(
        <template>
          <Form @data={{data}} @onSubmit={{submit}} as |form|>
            <form.Field
              @name="foo"
              @title="Foo"
              @type="category-chooser"
              as |field|
            >
              <field.Control @multiple={{true}} />
            </form.Field>
          </Form>
        </template>
      );

      assert.dom(CONTROL).includesText("Remote", "the fetched category shows");
      await formKit().submit();
      assert.deepEqual(data.foo, [9900], "and stays in the value");
    });

    test("rendering a held value does not dirty the form", async function (assert) {
      let api;
      const registerApi = (formApi) => (api = formApi);
      const data = { foo: 2 };

      await render(
        <template>
          <Form @data={{data}} @onRegisterApi={{registerApi}} as |form|>
            <form.Field
              @name="foo"
              @title="Foo"
              @type="category-chooser"
              as |field|
            >
              <field.Control />
            </form.Field>
          </Form>
        </template>
      );

      assert.false(api.isDirty);
    });
  }
);

module(
  "Integration | Component | FormKit | Controls | CategoryChooser (new select controls)",
  function (hooks) {
    setupRenderingTest(hooks);

    hooks.beforeEach(function () {
      this.siteSettings.enable_new_select_controls = true;
    });

    test("the control is a select-category that stores an id", async function (assert) {
      withPluginApi((api) =>
        api.registerValueTransformer("select-customizations", ({ value }) => {
          value.forKind("select-category", (spec) =>
            spec.row((row) => row.classes.push("x-select-category"))
          );
        })
      );
      let data = { foo: null };
      const submit = (x) => (data = x);

      await render(
        <template>
          <Form @data={{data}} @onSubmit={{submit}} as |form|>
            <form.Field
              @name="foo"
              @title="Foo"
              @type="category-chooser"
              as |field|
            >
              <field.Control />
            </form.Field>
          </Form>
        </template>
      );

      assert.dom(`${CONTROL}.select-kit`).doesNotExist();

      await dSelect(CONTROL).open();
      assert.dom("[role='option'].x-select-category").exists();

      await dSelect(CONTROL).select(1);
      await formKit().submit();

      assert.strictEqual(data.foo, 1);
    });

    test("@multiple stores ids and the helpers report and pick them", async function (assert) {
      let data = { foo: [2] };
      const submit = (x) => (data = x);

      await render(
        <template>
          <Form @data={{data}} @onSubmit={{submit}} as |form|>
            <form.Field
              @name="foo"
              @title="Foo"
              @type="category-chooser"
              as |field|
            >
              <field.Control @multiple={{true}} />
            </form.Field>
          </Form>
        </template>
      );

      assert.form().field("foo").hasValue("2");
      await formKit().field("foo").select(1);
      await formKit().submit();

      assert.deepEqual(data.foo, [2, 1]);
    });

    test("rendering a held value does not dirty the form", async function (assert) {
      let api;
      const registerApi = (formApi) => (api = formApi);
      const data = { foo: 2 };

      await render(
        <template>
          <Form @data={{data}} @onRegisterApi={{registerApi}} as |form|>
            <form.Field
              @name="foo"
              @title="Foo"
              @type="category-chooser"
              as |field|
            >
              <field.Control />
            </form.Field>
          </Form>
        </template>
      );

      assert.false(api.isDirty);
    });

    test("the field's title names the control and its description describes it", async function (assert) {
      await render(
        <template>
          <Form as |form|>
            <form.Field
              @description="Pick one"
              @name="foo"
              @title="Foo"
              @type="category-chooser"
              as |field|
            >
              <field.Control />
            </form.Field>
          </Form>
        </template>
      );

      const control = combobox();
      const name =
        referencedText(control.getAttribute("aria-labelledby")) ||
        control.getAttribute("aria-label") ||
        document.querySelector(`label[for='${control.id}']`)?.textContent;

      assert.true(/Foo/.test(name ?? ""), `named by the field title: ${name}`);
      assert.true(
        referencedText(control.getAttribute("aria-describedby")).includes(
          "Pick one"
        ),
        "described by the field description"
      );
    });

    test("the placeholder key is translated", async function (assert) {
      await render(
        <template>
          <Form as |form|>
            <form.Field
              @name="foo"
              @title="Foo"
              @type="category-chooser"
              as |field|
            >
              <field.Control @placeholder="category.choose" />
            </form.Field>
          </Form>
        </template>
      );

      assert.strictEqual(placeholderText(), i18n("category.choose"));
    });

    test("the placeholder shows its translation as written", async function (assert) {
      I18n.translations[I18n.locale].js.test = { prompt: "R&amp;D &lt;b&gt;" };

      await render(
        <template>
          <Form as |form|>
            <form.Field
              @name="foo"
              @title="Foo"
              @type="category-chooser"
              as |field|
            >
              <field.Control @placeholder="test.prompt" />
            </form.Field>
          </Form>
        </template>
      );

      assert.strictEqual(placeholderText(), "R&amp;D &lt;b&gt;");
    });

    test("disabled fields lock the control", async function (assert) {
      await render(
        <template>
          <Form as |form|>
            <form.Field
              @disabled={{true}}
              @name="foo"
              @title="Foo"
              @type="category-chooser"
              as |field|
            >
              <field.Control />
            </form.Field>
          </Form>
        </template>
      );

      assert
        .dom(`${CONTROL}.d-select__trigger, ${CONTROL} .d-select__trigger`)
        .hasClass("--disabled");
    });

    test("a field error marks the control invalid", async function (assert) {
      await render(
        <template>
          <Form as |form|>
            <form.Field
              @name="foo"
              @title="Foo"
              @type="category-chooser"
              @validation="required"
              as |field|
            >
              <field.Control />
            </form.Field>
          </Form>
        </template>
      );
      await formKit().submit();

      assert.strictEqual(combobox().getAttribute("aria-invalid"), "true");
    });

    test("category rules reach the picker", async function (assert) {
      const exclude = [1];

      await render(
        <template>
          <Form as |form|>
            <form.Field
              @name="foo"
              @title="Foo"
              @type="category-chooser"
              as |field|
            >
              <field.Control
                @exclude={{exclude}}
                @multiple={{true}}
                @subcategories={{false}}
                @uncategorized={{false}}
              />
            </form.Field>
          </Form>
        </template>
      );

      await dSelect(CONTROL).search("bug");
      assert.deepEqual(optionValues(), [], "excluded");
      await dSelect(CONTROL).search("uncategorized");
      assert.deepEqual(optionValues(), [], "no uncategorized");
      await dSelect(CONTROL).search("spec");
      assert.deepEqual(optionValues(), [], "no subcategories");
      await dSelect(CONTROL).search("meta");
      assert.deepEqual(optionValues(), ["3"], "other categories are offered");
    });

    test("@permission create offers only categories the user can post in", async function (assert) {
      Site.current().updateCategories([
        { id: 9901, name: "Readable only", slug: "readable", permission: null },
      ]);

      await render(
        <template>
          <Form as |form|>
            <form.Field
              @name="see"
              @title="See"
              @type="category-chooser"
              as |field|
            >
              <field.Control />
            </form.Field>
            <form.Field
              @name="create"
              @title="Create"
              @type="category-chooser"
              as |field|
            >
              <field.Control @permission="create" />
            </form.Field>
          </Form>
        </template>
      );

      await dSelect(`[data-name='see'] ${CONTROL}`).search("readable");
      assert.deepEqual(
        optionValues(),
        ["9901"],
        "visible categories by default"
      );
      await dSelect(`[data-name='see'] ${CONTROL}`).close();

      await dSelect(`[data-name='create'] ${CONTROL}`).search("readable");
      assert.deepEqual(optionValues(), [], "hidden when creating");
    });
  }
);

for (const newControls of [false, true]) {
  module(
    `Integration | Component | FormKit | Controls | CategoryChooser ids (${newControls ? "new select controls" : "legacy"})`,
    function (hooks) {
      setupRenderingTest(hooks);

      hooks.beforeEach(function () {
        this.siteSettings.enable_new_select_controls = newControls;
      });

      for (const multiple of [false, true]) {
        test(`helpers select and report ${multiple ? "multiple" : "single"} ids`, async function (assert) {
          let data = { foo: multiple ? [2] : 2 };
          const submit = (value) => (data = value);
          await render(
            <template>
              <Form @data={{data}} @onSubmit={{submit}} as |form|>
                <form.Field
                  @name="foo"
                  @title="Foo"
                  @type="category-chooser"
                  as |field|
                >
                  <field.Control @multiple={{multiple}} />
                </form.Field>
              </Form>
            </template>
          );
          assert.form().field("foo").hasValue("2", "held id is reported");
          await formKit().field("foo").select(1);
          assert
            .form()
            .field("foo")
            .hasValue(multiple ? "2,1" : "1", "picked ids are reported");
          await formKit().submit();
          assert.deepEqual(
            data.foo,
            multiple ? [2, 1] : 1,
            "form stores numeric ids"
          );
        });

        test(`lazy ${multiple ? "multiple" : "single"} ids survive hydration and a later pick without a mount emission`, async function (assert) {
          Site.current().set("lazy_load_categories", true);
          const remote = [
            { id: 1, name: "Picked", slug: "picked", permission: 1 },
            { id: 9900, name: "Remote", slug: "remote" },
            { id: 9901, name: "Other remote", slug: "other-remote" },
          ];
          pretender.get("/categories/find", (request) => {
            const ids = [request.queryParams.ids].flat().map(Number);
            return response({
              categories: remote.filter(({ id }) => ids.includes(id)),
            });
          });
          pretender.post("/categories/search", () =>
            response({
              categories: [
                { id: 1, name: "Picked", slug: "picked", permission: 1 },
              ],
              ancestors: [],
              categories_count: 1,
            })
          );
          let api;
          const registerApi = (value) => (api = value);
          let data = { foo: multiple ? [9900, 9901] : 9900 };
          const submit = (value) => (data = value);
          await render(
            <template>
              <Form
                @data={{data}}
                @onRegisterApi={{registerApi}}
                @onSubmit={{submit}}
                as |form|
              >
                <form.Field
                  @name="foo"
                  @title="Foo"
                  @type="category-chooser"
                  as |field|
                >
                  <field.Control @multiple={{multiple}} />
                </form.Field>
              </Form>
            </template>
          );
          assert
            .dom(CONTROL)
            .includesText("Remote", "unloaded held category resolves");
          assert.false(api.isDirty, "hydration does not emit");
          if (multiple) {
            assert
              .dom(CONTROL)
              .includesText("Other remote", "all held categories resolve");
          }
          await formKit().field("foo").select(1);
          await formKit().submit();
          assert.deepEqual(
            data.foo,
            multiple ? [9900, 9901, 1] : 1,
            "editing keeps the held ids in multiple mode"
          );
        });
      }

      test("clearing a single selection stores null", async function (assert) {
        let data = { foo: 1 };
        const submit = (value) => (data = value);
        await render(
          <template>
            <Form @data={{data}} @onSubmit={{submit}} as |form|>
              <form.Field
                @name="foo"
                @title="Foo"
                @type="category-chooser"
                as |field|
              >
                <field.Control @placeholder="category.choose" />
              </form.Field>
            </Form>
          </template>
        );
        if (newControls) {
          await dSelect(CONTROL).clear();
        } else {
          await click(selectKit(CONTROL).clearButton());
        }
        await formKit().submit();
        assert.strictEqual(data.foo, null, "clearing stores null");
      });

      test("maximum caps multiple selection without changing its shape", async function (assert) {
        let data = { foo: [2] };
        const submit = (value) => (data = value);
        await render(
          <template>
            <Form @data={{data}} @onSubmit={{submit}} as |form|>
              <form.Field
                @name="foo"
                @title="Foo"
                @type="category-chooser"
                as |field|
              >
                <field.Control @maximum={{2}} @multiple={{true}} />
              </form.Field>
            </Form>
          </template>
        );
        await formKit().field("foo").select(1);
        if (newControls) {
          await dSelect(CONTROL).open();
          assert
            .dom("[role='option'][data-value='3']")
            .hasAttribute(
              "aria-disabled",
              "true",
              "a third category cannot be picked"
            );
          await dSelect(CONTROL).close();
        } else {
          await selectKit(CONTROL).expand();
          await selectKit(CONTROL).selectRowByValue(3);
          assert
            .dom(".select-kit-error")
            .exists("a third category is rejected");
        }
        await formKit().submit();
        assert.deepEqual(data.foo, [2, 1], "maximum keeps an array of ids");
      });
    }
  );
}
