import { click, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { forceMobile } from "discourse/lib/mobile";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import DNavItem from "discourse/ui-kit/d-nav-item";
import DPageHeader from "discourse/ui-kit/d-page-header";
import DPageSubheader from "discourse/ui-kit/d-page-subheader";
import { i18n } from "discourse-i18n";

module("Integration | ui-kit | DPageSubheader", function (hooks) {
  setupRenderingTest(hooks);

  test("@titleLabel", async function (assert) {
    await render(
      <template><DPageSubheader @titleLabel={{i18n "admin.title"}} /></template>
    );
    assert
      .dom(".d-page-subheader__title")
      .exists()
      .hasText(i18n("admin.title"));
  });

  test("no @descriptionLabel", async function (assert) {
    await render(<template><DPageSubheader /></template>);
    assert.dom(".d-page-subheader__description").doesNotExist();
  });

  test("@descriptionLabel", async function (assert) {
    await render(
      <template>
        <DPageSubheader @descriptionLabel={{i18n "admin.badges.description"}} />
      </template>
    );
    assert
      .dom(".d-page-subheader__description")
      .exists()
      .hasText(i18n("admin.badges.description"));
  });

  test("no @learnMoreUrl", async function (assert) {
    await render(<template><DPageSubheader /></template>);
    assert.dom(".d-page-subheader__learn-more").doesNotExist();
  });

  test("@learnMoreUrl", async function (assert) {
    await render(
      <template>
        <DPageSubheader
          @descriptionLabel={{i18n "admin.badges.description"}}
          @learnMoreUrl="https://meta.discourse.org/t/96331"
        />
      </template>
    );
    assert.dom(".d-page-subheader__learn-more").exists();
    assert
      .dom(".d-page-subheader__learn-more a")
      .hasText("Learn more…")
      .hasAttribute("href", "https://meta.discourse.org/t/96331");
  });

  test("renders all types of action buttons in yielded <:actions>", async function (assert) {
    let actionCalled = false;
    const someAction = () => {
      actionCalled = true;
    };

    await render(
      <template>
        <DPageSubheader>
          <:actions as |actions|>
            <actions.Primary
              class="new-badge"
              @icon="plus"
              @label="admin.badges.new"
              @route="adminBadges.show"
              @routeModels="new"
            />

            <actions.Default
              class="award-badge"
              @icon="upload"
              @label="admin.badges.mass_award.title"
              @route="adminBadges.award"
              @routeModels="new"
            />

            <actions.Danger
              class="edit-groupings-btn"
              @action={{someAction}}
              @icon="gear"
              @label="admin.badges.group_settings"
              @title="admin.badges.group_settings"
            />
          </:actions>
        </DPageSubheader>
      </template>
    );

    assert
      .dom(
        ".d-page-subheader__actions .d-page-action-button.new-badge.btn.btn-small.btn-primary"
      )
      .exists();
    assert
      .dom(
        ".d-page-subheader__actions .d-page-action-button.award-badge.btn.btn-small.btn-default"
      )
      .exists();
    assert
      .dom(
        ".d-page-subheader__actions .d-page-action-button.edit-groupings-btn.btn.btn-small.btn-danger"
      )
      .exists();

    await click(".edit-groupings-btn");
    assert.true(actionCalled);
  });
  test("@actionsPlacement='tabs' renders actions in the header tabs row", async function (assert) {
    await render(
      <template>
        <DPageHeader @titleLabel="Header">
          <:tabs>
            <DNavItem @label="admin.badges.title" @route="adminBadges" />
          </:tabs>
        </DPageHeader>
        <DPageSubheader @actionsPlacement="tabs" @titleLabel="Subheader">
          <:actions as |actions|>
            <actions.Primary class="new-badge" @label="admin.badges.new" />
          </:actions>
        </DPageSubheader>
      </template>
    );

    assert
      .dom(".d-nav-submenu .d-nav-submenu__actions .new-badge")
      .exists("actions render next to the tabs");
    assert
      .dom(".d-page-subheader")
      .doesNotExist("the subheader is not rendered");
  });

  test("@actionsPlacement='tabs' falls back when the header hides its tabs", async function (assert) {
    await render(
      <template>
        <DPageHeader @hideTabs={{true}} @titleLabel="Header" />
        <DPageSubheader @actionsPlacement="tabs" @titleLabel="Subheader">
          <:actions as |actions|>
            <actions.Primary class="new-badge" @label="admin.badges.new" />
          </:actions>
        </DPageSubheader>
      </template>
    );

    assert.dom(".d-page-subheader__title").hasText("Subheader");
    assert.dom(".d-page-subheader__actions .new-badge").exists();
  });

  test("@actionsPlacement='tabs' keeps the description", async function (assert) {
    await render(
      <template>
        <DPageHeader @titleLabel="Header" />
        <DPageSubheader
          @actionsPlacement="tabs"
          @descriptionLabel={{i18n "admin.badges.description"}}
          @titleLabel="Subheader"
        >
          <:actions as |actions|>
            <actions.Primary class="new-badge" @label="admin.badges.new" />
          </:actions>
        </DPageSubheader>
      </template>
    );

    assert.dom(".d-page-subheader__title").doesNotExist();
    assert
      .dom(".d-page-subheader__description")
      .hasText(i18n("admin.badges.description"));
  });
});

module("Integration | ui-kit | DPageSubheader | Mobile", function (hooks) {
  hooks.beforeEach(function () {
    forceMobile();
  });

  setupRenderingTest(hooks);

  test("action buttons become a dropdown on mobile", async function (assert) {
    await render(
      <template>
        <DPageSubheader>
          <:actions as |actions|>
            <actions.Primary
              class="new-badge"
              @icon="plus"
              @label="admin.badges.new"
              @route="adminBadges.show"
              @routeModels="new"
            />

            <actions.Default
              class="award-badge"
              @icon="upload"
              @label="admin.badges.mass_award.title"
              @route="adminBadges.award"
              @routeModels="new"
            />
          </:actions>
        </DPageSubheader>
      </template>
    );

    assert
      .dom(
        ".d-page-subheader .fk-d-menu__trigger.d-page-subheader-mobile-actions-trigger"
      )
      .exists();

    await click(".d-page-subheader-mobile-actions-trigger");

    assert
      .dom(".dropdown-menu.d-page-subheader__mobile-actions .new-badge")
      .exists();
  });
});
