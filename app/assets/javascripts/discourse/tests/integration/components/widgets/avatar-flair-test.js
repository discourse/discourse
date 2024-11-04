import { render } from "@ember/test-helpers";
import { hbs } from "ember-cli-htmlbars";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { exists } from "discourse/tests/helpers/qunit-helpers";

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
    assert.dom(".avatar-flair").hasStyle({
      backgroundColor: "rgb(204, 0, 0)",
      color: "rgb(255, 255, 255)",
    });
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
