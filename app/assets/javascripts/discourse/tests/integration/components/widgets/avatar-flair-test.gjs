import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import MountWidget from "discourse/components/mount-widget";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

module("Integration | Component | Widget | avatar-flair", function (hooks) {
  setupRenderingTest(hooks);

  test("avatar flair with an icon", async function (assert) {
    const args = {
      flair_url: "bars",
      flair_bg_color: "CC0000",
      flair_color: "FFFFFF",
    };

    await render(
      <template><MountWidget @widget="avatar-flair" @args={{args}} /></template>
    );

    assert.dom(".avatar-flair").exists("has the tag");
    assert.dom("svg.d-icon-bars").exists("has the svg icon");
    assert.dom(".avatar-flair").hasStyle({
      backgroundColor: "rgb(204, 0, 0)",
      color: "rgb(255, 255, 255)",
    });
  });

  test("avatar flair with an image", async function (assert) {
    const args = {
      flair_url: "/images/avatar.png",
    };

    await render(
      <template><MountWidget @widget="avatar-flair" @args={{args}} /></template>
    );

    assert.dom(".avatar-flair").exists("has the tag");
    assert.dom("svg").doesNotExist("does not have an svg icon");
  });
});
