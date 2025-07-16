import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import {
  fillIn,
  render,
  triggerEvent,
  triggerKeyEvent,
} from "@ember/test-helpers";
import { module, test } from "qunit";
import FilterTips from "discourse/components/discovery/filter-tips";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";

module("Integration | Component | discovery | filter-tips", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    this.tips = [
      { name: "category:", description: "Filter category", priority: 1 },
      { name: "tag:", description: "Filter tag", priority: 1 },
      { name: "status:", description: "Filter status", priority: 1 },
      { name: "status:open", description: "Open topics" },
    ];
    this.query = "";
    this.update = (value) => {
      this.set("query", value);
      this.inputElement.value = value;
    };
    this.blockEnter = () => {};
    this.capture = (el) => (this.inputElement = el);

    this.site.categories = [{ id: 1, name: "Support", slug: "support" }];
    pretender.get("/tags/filter/search.json", () =>
      response({ results: [{ name: "ember", count: 1 }] })
    );
    pretender.get("/u/search/users", () => response({ users: [] }));
  });

  test("basic navigation", async function (assert) {
    const self = this;
    await render(
      <template>
        <input id="q" {{didInsert self.capture}} />
        <FilterTips
          @tips={{self.tips}}
          @queryString={{self.query}}
          @onSelectTip={{self.update}}
          @blockEnterSubmit={{self.blockEnter}}
          @inputElement={{self.inputElement}}
        />
      </template>
    );

    await triggerEvent("#q", "focus");
    assert.dom(".filter-tip").exists({ count: 3 }, "shows tips on focus");
    assert.dom(".filter-tip.selected").doesNotExist("no selection yet");
    assert.dom("#q").hasValue("");

    await triggerKeyEvent("#q", "keydown", "ArrowDown");
    assert.dom(".filter-tip.selected .filter-name").hasText("category:");

    await triggerKeyEvent("#q", "keydown", "ArrowDown");
    assert.dom(".filter-tip.selected .filter-name").hasText("tag:");

    await triggerKeyEvent("#q", "keydown", "ArrowUp");
    assert.dom(".filter-tip.selected .filter-name").hasText("category:");
  });

  test("selecting a tip with tab", async function (assert) {
    const self = this;
    await render(
      <template>
        <input id="q" {{didInsert self.capture}} />
        <FilterTips
          @tips={{self.tips}}
          @queryString={{self.query}}
          @onSelectTip={{self.update}}
          @blockEnterSubmit={{self.blockEnter}}
          @inputElement={{self.inputElement}}
        />
      </template>
    );

    await triggerEvent("#q", "focus");
    await triggerKeyEvent("#q", "keydown", "ArrowDown");
    await triggerKeyEvent("#q", "keydown", "Tab");

    assert.strictEqual(this.query, "category:", "tab adds filter");
    assert
      .dom(".filter-tip")
      .exists({ count: 1 }, "tips for category shows up");
    assert.dom("#q").hasValue("category:");

    await triggerEvent("#q", "focus");
    await triggerKeyEvent("#q", "keydown", "Tab");

    assert.dom(".filter-tip").exists({ count: 3 }, "tips show again");
    assert.dom(".filter-tip.selected").doesNotExist("selection cleared");
    assert.dom("#q").hasValue("category:support ", "category slug added");
  });

  test("searching tag values", async function (assert) {
    const self = this;
    await render(
      <template>
        <input id="q" {{didInsert self.capture}} />
        <FilterTips
          @tips={{self.tips}}
          @queryString={{self.query}}
          @onSelectTip={{self.update}}
          @blockEnterSubmit={{self.blockEnter}}
          @inputElement={{self.inputElement}}
        />
      </template>
    );

    await triggerEvent("#q", "focus");
    await fillIn("#q", "tag:e");

    assert.dom(".filter-value").exists("shows tag results");
    assert.dom(".filter-value").hasText("tag:ember (1)");

    await triggerKeyEvent("#q", "keydown", "ArrowDown");
    assert.dom(".filter-tip.selected .filter-value").hasText("tag:ember (1)");

    await triggerKeyEvent("#q", "keydown", "Enter");
    assert.strictEqual(this.query, "tag:ember ", "enter selects result");
  });

  test("escape hides suggestions", async function (assert) {
    const self = this;
    await render(
      <template>
        <input id="q" {{didInsert self.capture}} />
        <FilterTips
          @tips={{self.tips}}
          @queryString={{self.query}}
          @onSelectTip={{self.update}}
          @blockEnterSubmit={{self.blockEnter}}
          @inputElement={{self.inputElement}}
        />
      </template>
    );

    await triggerEvent("#q", "focus");
    assert.dom(".filter-tip").exists("tips visible");
    await triggerKeyEvent("#q", "keydown", "Escape");
    assert.dom(".filter-tip").doesNotExist("tips hidden on escape");

    await fillIn("#q", "status");
    await triggerEvent("#q", "input");
    await triggerKeyEvent("#q", "keydown", "Escape");
    assert.strictEqual(this.query, "", "query not changed");
    assert.dom("#q").hasValue("status", "input unchanged");
    assert.dom(".filter-tip").doesNotExist("tips remain hidden");
  });
});
