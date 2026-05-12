import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import DAvatarFlair from "discourse/ui-kit/d-avatar-flair";

function renderComponent(flairArgs) {
  return render(
    <template>
      <DAvatarFlair
        @flairBgColor={{flairArgs.flair_bg_color}}
        @flairColor={{flairArgs.flair_color}}
        @flairName={{flairArgs.flair_name}}
        @flairUrl={{flairArgs.flair_url}}
      />
    </template>
  );
}

module("Integration | ui-kit | DAvatarFlair", function (hooks) {
  setupRenderingTest(hooks);

  test("renders the root element with the avatar-flair class", async function (assert) {
    await renderComponent({ flair_url: "bars" });
    assert.dom(".avatar-flair").exists();
  });

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

  test("adds the avatar-flair-<flairName> class hook", async function (assert) {
    await renderComponent({ flair_url: "bars", flair_name: "staff" });
    assert.dom(".avatar-flair.avatar-flair-staff").exists();
  });

  test("adds the rounded class when @flairBgColor is present", async function (assert) {
    await renderComponent({ flair_url: "bars", flair_bg_color: "CC0000" });
    assert.dom(".avatar-flair.rounded").exists();
  });

  test("does not add the rounded class when @flairBgColor is absent", async function (assert) {
    await renderComponent({ flair_url: "bars" });
    assert.dom(".avatar-flair").doesNotHaveClass("rounded");
  });

  test("adds the avatar-flair-image class for image URLs", async function (assert) {
    await renderComponent({ flair_url: "/images/avatar.png" });
    assert.dom(".avatar-flair.avatar-flair-image").exists();
  });

  test("does not add the avatar-flair-image class for icon names", async function (assert) {
    await renderComponent({ flair_url: "bars" });
    assert.dom(".avatar-flair").doesNotHaveClass("avatar-flair-image");
  });

  test("sets background-image as the URL for image flairs", async function (assert) {
    await renderComponent({ flair_url: "/images/avatar.png" });
    assert
      .dom(".avatar-flair")
      .hasStyle({ backgroundImage: 'url("/images/avatar.png")' });
  });
});
