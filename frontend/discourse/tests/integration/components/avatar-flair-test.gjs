import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import AvatarFlair from "discourse/components/avatar-flair";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

function renderComponent(flairArgs) {
  return render(
    <template>
      <AvatarFlair
        @flairBgColor={{flairArgs.flair_bg_color}}
        @flairColor={{flairArgs.flair_color}}
        @flairName={{flairArgs.flair_name}}
        @flairUrl={{flairArgs.flair_url}}
      />
    </template>
  );
}

module("Integration | Component | AvatarFlair", function (hooks) {
  setupRenderingTest(hooks);

  test("avatar flair with an icon", async function (assert) {
    const flairArgs = {
      flair_url: "bars",
      flair_bg_color: "CC0000",
      flair_color: "FFFFFF",
      flair_name: "icon-avatar-flair",
    };

    await renderComponent(flairArgs);

    assert
      .dom(".avatar-flair")
      .exists("has the tag")
      .hasAttribute(
        "title",
        "icon-avatar-flair",
        "the title attribute is set correctly"
      );
    assert.dom("svg.d-icon-bars").exists("has the svg icon");
    assert.dom(".avatar-flair").hasStyle({
      backgroundColor: "rgb(204, 0, 0)",
      color: "rgb(255, 255, 255)",
    });
  });

  test("avatar flair with an image", async function (assert) {
    const flairArgs = {
      flair_url: "/images/avatar.png",
      flair_name: "image-avatar-flair",
    };

    await renderComponent(flairArgs);

    assert
      .dom(".avatar-flair")
      .exists("has the tag")
      .hasAttribute(
        "title",
        "image-avatar-flair",
        "the title attribute is set correctly"
      );
    assert.dom("svg").doesNotExist("does not have an svg icon");
  });
});
