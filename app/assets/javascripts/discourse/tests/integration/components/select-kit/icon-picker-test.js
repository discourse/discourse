import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { render } from "@ember/test-helpers";
import { hbs } from "ember-cli-htmlbars";
import selectKit from "discourse/tests/helpers/select-kit-helper";
import { queryAll } from "discourse/tests/helpers/qunit-helpers";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import { setIconList } from "discourse-common/lib/icon-library";

module("Integration | Component | select-kit/icon-picker", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    this.set("subject", selectKit());
    setIconList(["ad", "link"]);

    pretender.get("/svg-sprite/picker-search", () => {
      return response([
        { id: "ad", symbol: "" },
        { id: "bacon", symbol: "" },
        { id: "link", symbol: [] },
      ]);
    });
  });

  test("content", async function (assert) {
    await render(hbs`
      <IconPicker
        @name="icon"
        @value={{this.value}}
        @content={{this.content}}
      />
    `);

    await this.subject.expand();
    const icons = [...queryAll(".select-kit-row .name")].map(
      (el) => el.innerText
    );
    assert.deepEqual(icons, ["ad", "bacon", "link"]);
  });

  test("only available", async function (assert) {
    await render(hbs`
      <IconPicker
        @name="icon"
        @value={{this.value}}
        @content={{this.content}}
        @onlyAvailable={{true}}
      />
    `);

    await this.subject.expand();
    const icons = [...queryAll(".select-kit-row .name")].map(
      (el) => el.innerText
    );
    assert.deepEqual(icons, ["ad", "link"]);
  });
});
