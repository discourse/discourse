import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import dAvatar, {
  addExtraUserClasses,
  classesForUser,
  registerCustomAvatarHelper,
  renderAvatar,
} from "discourse/ui-kit/helpers/d-avatar";
import * as userAvatarModule from "discourse/ui-kit/helpers/d-user-avatar";

module("Integration | ui-kit | Helper | dAvatar", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    this.siteSettings.prioritize_username_in_ux = false;
    this.siteSettings.enable_names = true;
    this.user = {
      username: "login_name",
      name: "O'Name <&>",
      title: "Moderator",
      avatar_template: "/avatar/{size}.png",
    };
  });

  test("alt is empty by default", async function (assert) {
    const user = this.user;

    await render(<template>{{dAvatar user imageSize="tiny"}}</template>);

    assert.dom("img.avatar").hasAttribute("alt", "");
  });

  test("alt=true uses the display name and leaves the title alone", async function (assert) {
    const user = this.user;

    await render(
      <template>{{dAvatar user alt=true imageSize="tiny"}}</template>
    );

    assert.dom("img.avatar").hasAttribute("alt", user.name);
    assert.dom("img.avatar").hasAttribute("title", "Moderator");
  });

  test("an alt string is escaped as text", async function (assert) {
    const user = this.user;
    const alt = "' onerror='alert(1)";

    await render(
      <template>{{dAvatar user alt=alt imageSize="tiny"}}</template>
    );

    assert.dom("img.avatar").hasAttribute("alt", alt);
    assert
      .dom("img.avatar")
      .doesNotHaveAttribute("onerror", "it cannot break out of the attribute");
  });

  test("renders nothing without a user, username or avatar template", async function (assert) {
    const noUsername = { avatar_template: "/avatar/{size}.png" };
    const noTemplate = { username: "login_name" };

    await render(
      <template>
        <div class="none">{{dAvatar null}}</div>
        <div class="no-username">{{dAvatar noUsername}}</div>
        <div class="no-template">{{dAvatar noTemplate}}</div>
      </template>
    );

    assert.dom(".none").hasNoText();
    assert.dom(".none *").doesNotExist();
    assert.dom(".no-username *").doesNotExist();
    assert.dom(".no-template *").doesNotExist();
  });

  test("uses the user's title as the title", async function (assert) {
    const user = this.user;

    await render(<template>{{dAvatar user imageSize="tiny"}}</template>);

    assert
      .dom("img.avatar")
      .hasAttribute("title", "Moderator")
      .hasAttribute("width", "24");
  });

  test("names the user before the description without a title", async function (assert) {
    const user = { ...this.user, title: null, description: "Gizmo maker" };

    await render(<template>{{dAvatar user imageSize="tiny"}}</template>);

    assert.dom("img.avatar").hasAttribute("title", "O'Name <&> - Gizmo maker");
  });

  test("uses the display name as the title otherwise", async function (assert) {
    const user = { ...this.user, title: null };

    await render(<template>{{dAvatar user imageSize="tiny"}}</template>);

    assert.dom("img.avatar").hasAttribute("title", "O'Name <&>");
  });

  test("uses the username as the display name when usernames come first", async function (assert) {
    this.siteSettings.prioritize_username_in_ux = true;
    const user = { ...this.user, title: null };

    await render(<template>{{dAvatar user imageSize="tiny"}}</template>);

    assert.dom("img.avatar").hasAttribute("title", "login_name");
  });

  test("prefers the given title, and can ignore or hide it", async function (assert) {
    const user = this.user;

    await render(
      <template>
        <div class="given">{{dAvatar user title="Given" imageSize="tiny"}}</div>
        <div class="ignored">
          {{dAvatar user ignoreTitle=true imageSize="tiny"}}
        </div>
        <div class="hidden">{{dAvatar
            user
            hideTitle=true
            imageSize="tiny"
          }}</div>
      </template>
    );

    assert.dom(".given img").hasAttribute("title", "Given");
    assert.dom(".ignored img").hasAttribute("title", "O'Name <&>");
    assert.dom(".hidden img").doesNotHaveAttribute("title");
  });

  test("reads the properties from the given paths", async function (assert) {
    const user = {
      handle: "path_name",
      template: "/path/{size}.png",
      extras: "gadget",
    };

    await render(
      <template>
        {{dAvatar
          user
          usernamePath="handle"
          avatarTemplatePath="template"
          imageSize="tiny"
          loading="lazy"
        }}
      </template>
    );

    assert
      .dom("img.avatar.gadget")
      .hasAttribute("src", /\/path\/\d+\.png$/)
      .hasAttribute("title", "path_name")
      .hasAttribute("loading", "lazy");
  });

  test("adds the extra classes without user extras", async function (assert) {
    const user = this.user;

    await render(
      <template>
        {{dAvatar user extraClasses="gizmo" imageSize="tiny"}}
      </template>
    );

    assert.dom("img.avatar.gizmo").exists();
  });

  test("d-user-avatar re-exports the d-avatar helpers", function (assert) {
    assert.strictEqual(userAvatarModule.renderAvatar, renderAvatar);
    assert.strictEqual(
      userAvatarModule.addExtraUserClasses,
      addExtraUserClasses
    );
    assert.strictEqual(userAvatarModule.classesForUser, classesForUser);
    assert.strictEqual(
      userAvatarModule.registerCustomAvatarHelper,
      registerCustomAvatarHelper
    );
  });

  test("addExtraUserClasses leaves the arguments alone without extra classes", function (assert) {
    const args = { size: "tiny" };

    assert.strictEqual(addExtraUserClasses(this.user, args), args);
    assert.deepEqual(args, { size: "tiny" });
  });
});
