import { module, test } from "qunit";
import hbs from "htmlbars-inline-precompile";
import { render } from "@ember/test-helpers";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

module(
  "Discourse Chat | Unit | Helpers | tonable-emoji-title",
  function (hooks) {
    setupRenderingTest(hooks);

    test("When emoji is not tonable", async function (assert) {
      this.set("emoji", { name: "foo", tonable: false });
      this.set("diversity", 1);
      await render(hbs`{{tonable-emoji-title this.emoji this.diversity}}`);

      assert.equal(
        document.querySelector("#ember-testing").innerText.trim(),
        ":foo:"
      );
    });

    test("When emoji is tonable and diversity is 1", async function (assert) {
      this.set("emoji", { name: "foo", tonable: true });
      this.set("diversity", 1);
      await render(hbs`{{tonable-emoji-title this.emoji this.diversity}}`);

      assert.equal(
        document.querySelector("#ember-testing").innerText.trim(),
        ":foo:"
      );
    });

    test("When emoji is tonable and diversity is greater than 1", async function (assert) {
      this.set("emoji", { name: "foo", tonable: true });
      this.set("diversity", 2);
      await render(hbs`{{tonable-emoji-title this.emoji this.diversity}}`);

      assert.equal(
        document.querySelector("#ember-testing").innerText.trim(),
        ":foo:t2:"
      );
    });
  }
);
