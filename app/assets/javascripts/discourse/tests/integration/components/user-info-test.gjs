import { render, triggerEvent } from "@ember/test-helpers";
import { module, test } from "qunit";
import UserInfo from "discourse/components/user-info";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import DTooltips from "float-kit/components/d-tooltips";

module("Integration | Component | user-info", function (hooks) {
  setupRenderingTest(hooks);

  test("prioritized name", async function (assert) {
    const self = this;

    this.siteSettings.prioritize_username_in_ux = false;
    this.currentUser.name = "Evil Trout";

    await render(<template><UserInfo @user={{self.currentUser}} /></template>);

    assert.dom(".name").hasText("Evil Trout");
    assert.dom(".username").hasText("eviltrout");
  });

  test("prioritized username", async function (assert) {
    const self = this;

    this.siteSettings.prioritize_username_in_ux = true;
    this.currentUser.name = "Evil Trout";

    await render(<template><UserInfo @user={{self.currentUser}} /></template>);

    assert.dom(".username").hasText("eviltrout");
    assert.dom(".name").hasText("Evil Trout");
  });

  test("includeLink", async function (assert) {
    const self = this;

    await render(
      <template>
        <UserInfo
          @user={{self.currentUser}}
          @includeLink={{self.includeLink}}
        />
      </template>
    );

    this.set("includeLink", true);
    assert.dom(`.name-line a[href="/u/${this.currentUser.username}"]`).exists();

    this.set("includeLink", false);
    assert
      .dom(`.name-line a[href="/u/${this.currentUser.username}"]`)
      .doesNotExist();
  });

  test("includeAvatar", async function (assert) {
    const self = this;

    await render(
      <template>
        <UserInfo
          @user={{self.currentUser}}
          @includeAvatar={{self.includeAvatar}}
        />
      </template>
    );

    this.set("includeAvatar", true);
    assert.dom(".user-image").exists();

    this.set("includeAvatar", false);
    assert.dom(".user-image").doesNotExist();
  });

  test("shows status if enabled and user has status", async function (assert) {
    const self = this;

    this.currentUser.name = "Evil Trout";
    this.currentUser.status = { emoji: "tooth", description: "off to dentist" };

    await render(
      <template>
        <UserInfo @user={{self.currentUser}} @showStatus={{true}} />
      </template>
    );

    assert.dom(".user-status-message").exists();
  });

  test("doesn't show status if enabled but user doesn't have status", async function (assert) {
    const self = this;

    this.currentUser.name = "Evil Trout";

    await render(
      <template>
        <UserInfo @user={{self.currentUser}} @showStatus={{true}} />
      </template>
    );

    assert.dom(".user-status-message").doesNotExist();
  });

  test("doesn't show status if disabled", async function (assert) {
    const self = this;

    this.currentUser.name = "Evil Trout";
    this.currentUser.status = { emoji: "tooth", description: "off to dentist" };

    await render(
      <template>
        <UserInfo @user={{self.currentUser}} @showStatus={{false}} />
      </template>
    );

    assert.dom(".user-status-message").doesNotExist();
  });

  test("doesn't show status by default", async function (assert) {
    const self = this;

    this.currentUser.name = "Evil Trout";
    this.currentUser.status = { emoji: "tooth", description: "off to dentist" };

    await render(<template><UserInfo @user={{self.currentUser}} /></template>);

    assert.dom(".user-status-message").doesNotExist();
  });

  test("doesn't show status description by default", async function (assert) {
    const self = this;

    this.currentUser.name = "Evil Trout";
    this.currentUser.status = { emoji: "tooth", description: "off to dentist" };

    await render(
      <template>
        <UserInfo @user={{self.currentUser}} @showStatus={{true}} />
      </template>
    );

    assert
      .dom(".user-status-message .user-status-message-description")
      .doesNotExist();
  });

  test("shows status description if enabled", async function (assert) {
    const self = this;

    this.currentUser.name = "Evil Trout";
    this.currentUser.status = { emoji: "tooth", description: "off to dentist" };

    await render(
      <template>
        <UserInfo
          @user={{self.currentUser}}
          @showStatus={{true}}
          @showStatusDescription={{true}}
        />
      </template>
    );

    assert
      .dom(".user-status-message .user-status-message-description")
      .exists();
  });

  test("shows status tooltip if enabled", async function (assert) {
    const self = this;

    this.currentUser.name = "Evil Trout";
    this.currentUser.status = { emoji: "tooth", description: "off to dentist" };

    await render(
      <template>
        <UserInfo @user={{self.currentUser}} @showStatus={{true}} /><DTooltips
        />
      </template>
    );
    await triggerEvent(".user-status-message", "pointermove");

    assert
      .dom("[data-content][data-identifier='user-status-message-tooltip']")
      .exists();
  });
});
