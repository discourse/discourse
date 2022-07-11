import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { render } from "@ember/test-helpers";
import { exists, query } from "discourse/tests/helpers/qunit-helpers";
import { hbs } from "ember-cli-htmlbars";

module("Integration | Component | Widget | avatar-flair", function (hooks) {
  setupRenderingTest(hooks);

  test("avatar flair with an icon", async function (assert) {
    this.set("args", {
      flair_url: "fa-bars",
      flair_bg_color: "CC0000",
      flair_color: "FFFFFF",
    });

    await render(
      hbs`<MountWidget @widget="avatar-flair" @args={{this.args}} />`
    );

    assert.ok(exists(".avatar-flair"), "it has the tag");
    assert.ok(exists("svg.d-icon-bars"), "it has the svg icon");
    assert.strictEqual(
      query(".avatar-flair").getAttribute("style"),
      "background-color: #CC0000; color: #FFFFFF; ",
      "it has styles"
    );
  });

  test("avatar flair with an image", async function (assert) {
    this.set("args", {
      flair_url: "/images/avatar.png",
    });

    await render(
      hbs`<MountWidget @widget="avatar-flair" @args={{this.args}} />`
    );

    assert.ok(exists(".avatar-flair"), "it has the tag");
    assert.ok(!exists("svg"), "it does not have an svg icon");
  });
});
