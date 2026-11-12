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

  test("forwards attributes while allowing the default tooltip to be overridden", async function (assert) {
    await render(
      <template>
        <DAvatarFlair
          aria-label="Custom description"
          class="custom-flair"
          role="img"
          title="Custom tooltip"
          @flairName="stable-name"
          @flairUrl="robot"
        />
      </template>
    );

    assert
      .dom(".avatar-flair")
      .hasClass(
        "avatar-flair-stable-name",
        "the flair name remains the CSS hook"
      );
    assert
      .dom(".avatar-flair")
      .hasClass("custom-flair", "caller classes are merged");
    assert
      .dom(".avatar-flair")
      .hasAttribute(
        "title",
        "Custom tooltip",
        "the caller can override the default tooltip"
      );
    assert
      .dom(".avatar-flair")
      .hasAttribute("role", "img", "semantic attributes are forwarded");
    assert
      .dom(".avatar-flair")
      .hasAttribute(
        "aria-label",
        "Custom description",
        "accessible labels are forwarded"
      );
  });
});
