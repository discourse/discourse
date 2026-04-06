import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import Form from "discourse/components/form";
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
          <Form @onSubmit={{mutateData}} @data={{data}} as |form|>
            <form.Field @type="tag-chooser" @name="foo" @title="Foo" as |field|>
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
              @type="tag-chooser"
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
            <form.Field @type="tag-chooser" @name="foo" @title="Foo" as |field|>
              <field.Control
                @showAllTags={{true}}
                @excludeSynonyms={{true}}
                @excludeTagsWithSynonyms={{true}}
                @categoryId={{123}}
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
            <form.Field @type="tag-chooser" @name="foo" @title="Foo" as |field|>
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
            <form.Field @type="tag-chooser" @name="foo" @title="Foo" as |field|>
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
            <form.Field @type="tag-chooser" @name="foo" @title="Foo" as |field|>
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
            <form.Field @type="tag-chooser" @name="foo" @title="Foo" as |field|>
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
