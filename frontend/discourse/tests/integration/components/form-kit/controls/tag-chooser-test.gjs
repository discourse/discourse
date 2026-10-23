import { click, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import Form from "discourse/components/form";
import { withPluginApi } from "discourse/lib/plugin-api";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import formKit from "discourse/tests/helpers/form-kit-helper";
import selectKit from "discourse/tests/helpers/select-kit-helper";
import { i18n } from "discourse-i18n";

module(
  "Integration | Component | FormKit | Controls | TagChooser",
  function (hooks) {
    setupRenderingTest(hooks);

    test("default", async function (assert) {
      let data = { foo: null };
      const mutateData = (x) => (data = x);

      await render(
        <template>
          <Form @data={{data}} @onSubmit={{mutateData}} as |form|>
            <form.Field @name="foo" @title="Foo" @type="tag-chooser" as |field|>
              <field.Control />
            </form.Field>
          </Form>
        </template>
      );

      assert.dom(".form-kit__control-tag-chooser").exists();

      const sk = selectKit(".form-kit__control-tag-chooser");
      await sk.expand();
      await sk.selectRowByName("monkey");

      await formKit().submit();

      assert.strictEqual(data.foo[0].name, "monkey");
    });

    test("when disabled", async function (assert) {
      await render(
        <template>
          <Form as |form|>
            <form.Field
              @disabled={{true}}
              @name="foo"
              @title="Foo"
              @type="tag-chooser"
              as |field|
            >
              <field.Control />
            </form.Field>
          </Form>
        </template>
      );

      assert.dom(".form-kit__control-tag-chooser.is-disabled").exists();
    });

    test("passes search props through", async function (assert) {
      let queryParams;

      pretender.get("/tags/filter/search", (request) => {
        queryParams = request.queryParams;

        return response({
          results: [{ id: 1, name: "monkey", slug: "monkey", count: 1 }],
        });
      });

      await render(
        <template>
          <Form as |form|>
            <form.Field @name="foo" @title="Foo" @type="tag-chooser" as |field|>
              <field.Control
                @categoryId={{123}}
                @excludeSynonyms={{true}}
                @excludeTagsWithSynonyms={{true}}
                @showAllTags={{true}}
              />
            </form.Field>
          </Form>
        </template>
      );

      await selectKit(".form-kit__control-tag-chooser").expand();

      assert.strictEqual(queryParams.categoryId, "123");
      assert.strictEqual(queryParams.excludeSynonyms, "true");
      assert.strictEqual(queryParams.excludeHasSynonyms, "true");
      assert.strictEqual(queryParams.filterForInput, undefined);
    });

    test("@placeholder", async function (assert) {
      await render(
        <template>
          <Form as |form|>
            <form.Field @name="foo" @title="Foo" @type="tag-chooser" as |field|>
              <field.Control @placeholder="groups.selector_placeholder" />
            </form.Field>
          </Form>
        </template>
      );

      await selectKit(".form-kit__control-tag-chooser").expand();

      assert
        .dom(".form-kit__control-tag-chooser .filter-input")
        .hasAttribute("placeholder", i18n("groups.selector_placeholder"));
    });

    test("@allowCreate", async function (assert) {
      this.site.can_create_tag = true;
      const chooser = selectKit(".form-kit__control-tag-chooser");

      await render(
        <template>
          <Form as |form|>
            <form.Field @name="foo" @title="Foo" @type="tag-chooser" as |field|>
              <field.Control />
            </form.Field>
          </Form>
        </template>
      );

      await chooser.expand();
      await chooser.fillInFilter("brandnew");

      assert
        .dom(".select-kit-row[data-value='brandnew']")
        .doesNotExist("it does not allow creating tags by default");

      await render(
        <template>
          <Form as |form|>
            <form.Field @name="foo" @title="Foo" @type="tag-chooser" as |field|>
              <field.Control @allowCreate={{true}} />
            </form.Field>
          </Form>
        </template>
      );

      await chooser.expand();
      await chooser.fillInFilter("brandnew");

      assert
        .dom(".select-kit-row[data-value='brandnew']")
        .exists("it allows creating tags when enabled");
    });

    test("@unlimited", async function (assert) {
      this.siteSettings.max_tags_per_topic = 1;
      let data = { foo: [{ id: 1, name: "monkey" }] };
      const mutateData = (x) => (data = x);

      await render(
        <template>
          <Form @data={{data}} @onSubmit={{mutateData}} as |form|>
            <form.Field @name="foo" @title="Foo" @type="tag-chooser" as |field|>
              <field.Control @unlimited={{true}} />
            </form.Field>
          </Form>
        </template>
      );

      const chooser = selectKit(".form-kit__control-tag-chooser");
      await chooser.expand();
      await chooser.selectRowByName("gazelle");
      await formKit().submit();

      assert.deepEqual(
        data.foo.map((tag) => tag.name),
        ["monkey", "gazelle"]
      );
      assert.dom(".select-kit-error").doesNotExist();
    });
  }
);

module(
  "Integration | Component | FormKit | Controls | TagChooser (new select controls)",
  function (hooks) {
    setupRenderingTest(hooks);

    hooks.beforeEach(function () {
      this.siteSettings.enable_new_select_controls = true;
    });

    test("a maximum of one renders a single select and keeps an array value", async function (assert) {
      let data = { foo: [{ id: 4, name: "cat" }] };
      const mutateData = (x) => (data = x);

      await render(
        <template>
          <Form @data={{data}} @onSubmit={{mutateData}} as |form|>
            <form.Field
              @maximum={{1}}
              @name="foo"
              @title="Foo"
              @type="tag-chooser"
              as |field|
            >
              <field.Control />
            </form.Field>
          </Form>
        </template>
      );

      assert
        .dom(".form-kit__control-tag-chooser.d-select__trigger")
        .doesNotHaveClass("--multiple", "one tag is a single select");

      await formKit().field("foo").selectByName("monkey");
      await formKit().submit();

      assert.true(Array.isArray(data.foo), "the field still stores an array");
      assert.deepEqual(
        data.foo.map((tag) => tag.name),
        ["monkey"],
        "the pick replaces the held tag"
      );
    });

    test("the control is a select-tag", async function (assert) {
      withPluginApi((api) =>
        api.registerValueTransformer("select-customizations", ({ value }) => {
          value.forKind("select-tag", (spec) =>
            spec.row((row) => row.classes.push("x-select-tag"))
          );
        })
      );

      await render(
        <template>
          <Form as |form|>
            <form.Field @name="foo" @title="Foo" @type="tag-chooser" as |field|>
              <field.Control />
            </form.Field>
          </Form>
        </template>
      );
      await click(".form-kit__control-tag-chooser.d-select__trigger");

      assert.dom("[role='option'].x-select-tag").exists();
    });

    test("@prioritizeRecentTags reaches the search", async function (assert) {
      this.siteSettings.prioritize_recently_used_tags = true;
      const requests = [];
      pretender.get("/tags/filter/search", (request) => {
        requests.push(request.queryParams);
        return response({ results: [{ id: 1, name: "monkey" }] });
      });

      await render(
        <template>
          <Form as |form|>
            <form.Field
              @name="foo"
              @prioritizeRecentTags={{true}}
              @title="Foo"
              @type="tag-chooser"
              as |field|
            >
              <field.Control />
            </form.Field>
          </Form>
        </template>
      );
      await click(".form-kit__control-tag-chooser.d-select__trigger");

      assert.strictEqual(requests.at(-1)?.prioritizeRecentTags, "true");
    });

    test("the control renders DSelect and submits tag objects", async function (assert) {
      let data = { foo: null };
      const mutateData = (x) => (data = x);

      await render(
        <template>
          <Form @data={{data}} @onSubmit={{mutateData}} as |form|>
            <form.Field @name="foo" @title="Foo" @type="tag-chooser" as |field|>
              <field.Control />
            </form.Field>
          </Form>
        </template>
      );

      assert.dom(".form-kit__control-tag-chooser.d-select").exists();
      assert.dom(".form-kit__control-tag-chooser.select-kit").doesNotExist();

      await formKit().field("foo").selectByName("monkey");
      await formKit().submit();

      assert.strictEqual(data.foo[0].name, "monkey");
    });

    test("the field's title names the control", async function (assert) {
      await render(
        <template>
          <Form as |form|>
            <form.Field
              @description="Pick some"
              @name="foo"
              @title="Foo"
              @type="tag-chooser"
              as |field|
            >
              <field.Control />
            </form.Field>
          </Form>
        </template>
      );

      const input = document.querySelector(
        ".form-kit__control-tag-chooser [role='combobox']"
      );
      const labelledBy = input.getAttribute("aria-labelledby");
      const name = labelledBy
        ? labelledBy
            .split(/\s+/)
            .map((id) => document.getElementById(id)?.textContent.trim())
            .join(" ")
        : (input.getAttribute("aria-label") ??
          document
            .querySelector(`label[for='${input.id}']`)
            ?.textContent.trim());
      assert.true(/Foo/.test(name ?? ""), `named by the field title: ${name}`);

      const described = (input.getAttribute("aria-describedby") ?? "")
        .split(/\s+/)
        .map((id) => document.getElementById(id)?.textContent.trim() ?? "")
        .join(" ");
      assert.true(described.includes("Pick some"), `described: ${described}`);
    });

    test("the placeholder key is translated", async function (assert) {
      await render(
        <template>
          <Form as |form|>
            <form.Field @name="foo" @title="Foo" @type="tag-chooser" as |field|>
              <field.Control @placeholder="tagging.choose_for_topic" />
            </form.Field>
          </Form>
        </template>
      );

      assert
        .dom(".form-kit__control-tag-chooser [role='combobox']")
        .hasAttribute("placeholder", i18n("tagging.choose_for_topic"));
    });

    test("disabled fields lock the control", async function (assert) {
      await render(
        <template>
          <Form as |form|>
            <form.Field
              @disabled={{true}}
              @name="foo"
              @title="Foo"
              @type="tag-chooser"
              as |field|
            >
              <field.Control />
            </form.Field>
          </Form>
        </template>
      );

      assert
        .dom(".form-kit__control-tag-chooser.d-select__trigger")
        .hasClass("--disabled");
    });

    test("search props reach the tag search", async function (assert) {
      let queryParams;
      pretender.get("/tags/filter/search", (request) => {
        queryParams = request.queryParams;
        return response({
          results: [{ id: 1, name: "monkey", slug: "monkey", count: 1 }],
        });
      });

      await render(
        <template>
          <Form as |form|>
            <form.Field @name="foo" @title="Foo" @type="tag-chooser" as |field|>
              <field.Control
                @categoryId={{123}}
                @excludeSynonyms={{true}}
                @excludeTagsWithSynonyms={{true}}
                @showAllTags={{true}}
              />
            </form.Field>
          </Form>
        </template>
      );
      await formKit().field("foo").selectByName("monkey");

      assert.strictEqual(queryParams.categoryId, "123");
      assert.strictEqual(queryParams.excludeSynonyms, "true");
      assert.strictEqual(queryParams.excludeHasSynonyms, "true");
      assert.strictEqual(queryParams.filterForInput, undefined);
    });

    test("the helpers deselect and report values", async function (assert) {
      const data = { foo: [{ id: 1, name: "monkey" }] };

      await render(
        <template>
          <Form @data={{data}} as |form|>
            <form.Field @name="foo" @title="Foo" @type="tag-chooser" as |field|>
              <field.Control />
            </form.Field>
          </Form>
        </template>
      );

      assert.form().field("foo").hasValue("1");
      await formKit().field("foo").deselectByName("monkey");
      assert.form().field("foo").hasValue("");
    });
  }
);
