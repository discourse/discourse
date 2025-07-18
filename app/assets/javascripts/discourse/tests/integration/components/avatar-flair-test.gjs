import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import AvatarFlair from "discourse/components/avatar-flair";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

function renderComponent(args) {
  return render(
    <template>
      <AvatarFlair
        @flairBgColor={{args.flair_bg_color}}
        @flairColor={{args.flair_color}}
        @flairName={{args.flair_name}}
        @flairUrl={{args.flair_url}}
      />
    </template>
  );
}

module("Integration | Component | AvatarFlair", function (hooks) {
  setupRenderingTest(hooks);

  test("avatar flair with an icon", async function (assert) {
    const args = {
      flair_url: "bars",
      flair_bg_color: "CC0000",
      flair_color: "FFFFFF",
      flair_name: "icon-avatar-flair",
    };

    await renderComponent(args);

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
    const args = {
      flair_url: "/images/avatar.png",
      flair_name: "image-avatar-flair",
    };

    await renderComponent(args);

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
