import { click, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import sinon from "sinon";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import {
  DangerActionListItem,
  DangerButton,
  DefaultActionListItem,
  DefaultButton,
  DPageActionButton,
  DPageActionListItem,
  PrimaryButton,
  WrappedActionListItem,
  WrappedButton,
} from "discourse/ui-kit/d-page-action-button";
import { i18n } from "discourse-i18n";

module("Integration | ui-kit | DPageActionButton", function (hooks) {
  setupRenderingTest(hooks);

  test("forwards its args to a small button", async function (assert) {
    let clicked = false;
    const onClick = () => (clicked = true);

    await render(
      <template>
        <DPageActionButton
          class="extra"
          @action={{onClick}}
          @icon="plus"
          @label="admin.badges.new"
          @title="admin.badges.new"
        />
        <DPageActionButton class="translated" @translatedLabel="Ready made" />
      </template>
    );

    assert
      .dom(".d-page-action-button.btn-small.extra")
      .hasText(i18n("admin.badges.new"), "@label is translated")
      .hasAttribute("title", i18n("admin.badges.new"), "@title is translated");
    assert.dom(".extra .d-icon-plus").exists("@icon is shown");
    assert.dom(".translated").hasText("Ready made", "@translatedLabel is used");

    await click(".extra");
    assert.true(clicked, "@action is called on click");
  });

  test("forwards @disabled, @isLoading, @route and @routeModels", async function (assert) {
    const transitionTo = sinon.stub(
      this.owner.lookup("service:router"),
      "transitionTo"
    );

    await render(
      <template>
        <DPageActionButton class="disabled-one" @disabled={{true}} />
        <DPageActionButton class="loading-one" @isLoading={{true}} />
        <DPageActionButton
          class="route-one"
          @route="adminBadges.show"
          @routeModels="new"
          @translatedLabel="New badge"
        />
      </template>
    );

    assert.dom(".disabled-one").isDisabled("@disabled disables the button");
    assert.dom(".loading-one").hasClass("is-loading", "@isLoading shows it");

    await click(".route-one");
    assert.true(
      transitionTo.calledOnceWith("adminBadges.show", "new"),
      "@route and @routeModels set where the button goes"
    );
  });

  test("the variants add their style", async function (assert) {
    await render(
      <template>
        <PrimaryButton class="primary" @disabled={{true}} />
        <DefaultButton class="default" />
        <DangerButton class="danger" />
      </template>
    );

    assert
      .dom(".d-page-action-button.primary")
      .hasClass("btn-primary")
      .isDisabled("PrimaryButton forwards @disabled");
    assert.dom(".d-page-action-button.default").hasClass("btn-default");
    assert.dom(".d-page-action-button.danger").hasClass("btn-danger");
  });

  test("WrappedButton wraps its block", async function (assert) {
    await render(
      <template>
        <WrappedButton><button class="uploader" type="button" /></WrappedButton>
      </template>
    );

    assert.dom(".d-page-action-wrapped-button .uploader").exists();
  });

  test("the list items render transparent buttons in menu items", async function (assert) {
    await render(
      <template>
        <ul>
          <DPageActionListItem class="plain" @translatedLabel="Plain" />
          <DefaultActionListItem class="default" @translatedLabel="Default" />
          <DangerActionListItem class="danger" @translatedLabel="Danger" />
        </ul>
      </template>
    );

    assert
      .dom("li.dropdown-menu__item.d-page-action-list-item")
      .exists({ count: 3 }, "each item is a menu item");
    assert
      .dom("li .d-page-action-button.btn-transparent.plain")
      .hasText("Plain");
    assert
      .dom("li .d-page-action-button.btn-transparent.btn-default.default")
      .exists("DefaultActionListItem adds its style");
    assert
      .dom("li .d-page-action-button.btn-transparent.btn-danger.danger")
      .exists("DangerActionListItem adds its style");
  });

  test("WrappedActionListItem yields the button class", async function (assert) {
    await render(
      <template>
        <ul>
          <WrappedActionListItem as |wrapped|>
            <button class="uploader {{wrapped.buttonClass}}" type="button" />
          </WrappedActionListItem>
        </ul>
      </template>
    );

    assert
      .dom("li.d-page-action-wrapped-list-item .uploader.btn-transparent")
      .exists();
  });
});
