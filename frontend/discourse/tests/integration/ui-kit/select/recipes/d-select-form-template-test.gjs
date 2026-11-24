import { tracked } from "@glimmer/tracking";
import { render, settled } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import { DSelect } from "discourse/tests/helpers/d-select-helper";
import DSelectFormTemplate from "discourse/ui-kit/select/recipes/form-templates/d-select-form-template";

/** Served in id order, which is not name order. */
const FORM_TEMPLATES = [
  { id: 1, name: "Workshop review", template: "- type: input" },
  { id: 2, name: "Repair question", template: "- type: input" },
  { id: 3, name: "Gig report", template: "- type: input" },
  { id: 4, name: "Parts compatibility", template: "- type: input" },
];

module(
  "Integration | ui-kit | select | recipes | DSelectFormTemplate",
  function (hooks) {
    setupRenderingTest(hooks);

    hooks.beforeEach(function () {
      this.requests = 0;
      this.formTemplates = FORM_TEMPLATES;
      pretender.get("/form-templates.json", () => {
        this.requests++;
        return response({ form_templates: this.formTemplates });
      });
    });

    test("form templates: lists them by name", async function (assert) {
      await render(<template><DSelectFormTemplate /></template>);
      await new DSelect().open();

      assert.dSelect().hasOptions([3, 4, 2, 1]);
    });

    test("form templates: offers only the given templates", async function (assert) {
      const ids = [1, 2, 99];

      await render(
        <template><DSelectFormTemplate @formTemplateIds={{ids}} /></template>
      );
      await new DSelect().open();

      assert.dSelect().hasOptions([2, 1], "an unknown id offers nothing");
    });

    test("form templates: a new set of ids changes the list without asking again", async function (assert) {
      const ids = tracked([1, 2]);

      await render(
        <template>
          <DSelectFormTemplate @formTemplateIds={{ids.value}} />
        </template>
      );
      await new DSelect().open();
      assert.dSelect().hasOptions([2, 1]);

      ids.value = [3, 4];
      await settled();

      assert.dSelect().hasOptions([3, 4]);
      assert.strictEqual(this.requests, 1, "the templates are fetched once");
    });

    test("form templates: one held template is named in the field and handed back as an id", async function (assert) {
      const value = tracked(2);
      const changes = [];
      const onChange = (id) => {
        changes.push(id);
        value.value = id;
      };

      await render(
        <template>
          <DSelectFormTemplate @onChange={{onChange}} @value={{value.value}} />
        </template>
      );

      assert.dSelect().hasLabel("Repair question");

      await new DSelect().select(3);

      assert.deepEqual(changes, [3], "the picked template's id, not a list");
      assert.dSelect().hasLabel("Gig report");
    });

    test("form templates: several held templates are named and handed back as ids", async function (assert) {
      const value = tracked([1, 4]);
      const changes = [];
      const onChange = (ids) => {
        changes.push(ids);
        value.value = ids;
      };

      await render(
        <template>
          <DSelectFormTemplate
            @multiple={{true}}
            @onChange={{onChange}}
            @value={{value.value}}
          />
        </template>
      );

      assert
        .dom(".d-select__chip")
        .exists({ count: 2 }, "a chip for each held template");
      assert
        .dom(".d-select__chip:nth-of-type(1)")
        .includesText("Workshop review");
      assert
        .dom(".d-select__chip:nth-of-type(2)")
        .includesText("Parts compatibility");

      await new DSelect().select(3);

      assert.deepEqual(changes, [[1, 4, 3]]);
    });

    test("form templates: names the field for what it holds", async function (assert) {
      await render(
        <template>
          <div class="single"><DSelectFormTemplate /></div>
          <div class="several"><DSelectFormTemplate @multiple={{true}} /></div>
        </template>
      );

      assert.dom(".single [role='combobox']").hasAria("label", "Form template");
      assert
        .dom(".several [role='combobox']")
        .hasAria("label", "Form templates");
      assert
        .dom(".several [role='combobox']")
        .hasAttribute("placeholder", "Select form templates");
    });

    test("form templates: says when there are none yet", async function (assert) {
      this.formTemplates = [];

      await render(<template><DSelectFormTemplate /></template>);
      await new DSelect().open();

      assert
        .dom(".d-select__empty")
        .hasText(
          "No form templates yet",
          "the field stays usable and says why"
        );
      assert.dSelect().isOpen();
    });

    test("form templates: a search with no match still says so", async function (assert) {
      await render(<template><DSelectFormTemplate /></template>);
      const select = new DSelect();
      await select.open();
      await select.search("tandem");

      assert.dom(".d-select__empty").includesText("tandem");
      assert
        .dom(".d-select__empty")
        .doesNotIncludeText("No form templates yet");
    });
  }
);
