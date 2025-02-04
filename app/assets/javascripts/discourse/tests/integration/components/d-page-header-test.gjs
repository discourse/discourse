import { click, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import DBreadcrumbsItem from "discourse/components/d-breadcrumbs-item";
import DPageHeader from "discourse/components/d-page-header";
import NavItem from "discourse/components/nav-item";
import { forceMobile } from "discourse/lib/mobile";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { i18n } from "discourse-i18n";

const DPageHeaderActionsTestComponent = <template>
  <div class="d-page-header-actions-test-component">
    <@actions.Default
      @route="adminBadges.award"
      @routeModels="new"
      @icon="upload"
      @label="admin.badges.mass_award.title"
      class="award-badge"
    />
  </div>
</template>;

module("Integration | Component | DPageHeader", function (hooks) {
  setupRenderingTest(hooks);

  test("no @titleLabel", async function (assert) {
    await render(<template><DPageHeader /></template>);
    assert.dom(".d-page-header__title").doesNotExist();
  });

  test("@titleLabel", async function (assert) {
    await render(<template>
      <DPageHeader @titleLabel={{i18n "admin.title"}} />
    </template>);
    assert.dom(".d-page-header__title").exists().hasText(i18n("admin.title"));
  });

  test("@shouldDisplay", async function (assert) {
    await render(<template>
      <DPageHeader @titleLabel="Wow so cool" @shouldDisplay={{false}} />
    </template>);
    assert.dom(".d-page-header").doesNotExist();
  });

  test("renders base breadcrumbs and yielded <:breadcrumbs>", async function (assert) {
    await render(<template>
      <DPageHeader @titleLabel={{i18n "admin.titile"}}>
        <:breadcrumbs>
          <DBreadcrumbsItem
            @path="/admin/badges"
            @label={{i18n "admin.badges.title"}}
          />
        </:breadcrumbs>
      </DPageHeader>
    </template>);

    assert
      .dom(".d-page-header__breadcrumbs .d-breadcrumbs__item")
      .exists({ count: 1 });
    assert
      .dom(".d-page-header__breadcrumbs .d-breadcrumbs__item:last-child")
      .hasText(i18n("admin.badges.title"));
  });

  test("no @descriptionLabel", async function (assert) {
    await render(<template><DPageHeader /></template>);
    assert.dom(".d-page-header__description").doesNotExist();
  });

  test("@descriptionLabel", async function (assert) {
    await render(<template>
      <DPageHeader @descriptionLabel={{i18n "admin.badges.description"}} />
    </template>);
    assert
      .dom(".d-page-header__description")
      .exists()
      .hasText(i18n("admin.badges.description"));
  });

  test("no @learnMoreUrl", async function (assert) {
    await render(<template><DPageHeader /></template>);
    assert.dom(".d-page-header__learn-more").doesNotExist();
  });

  test("@learnMoreUrl", async function (assert) {
    await render(<template>
      <DPageHeader
        @descriptionLabel={{i18n "admin.badges.description"}}
        @learnMoreUrl="https://meta.discourse.org/t/96331"
      />
    </template>);
    assert.dom(".d-page-header__learn-more").exists();
    assert
      .dom(".d-page-header__learn-more a")
      .hasText("Learn more…")
      .hasAttribute("href", "https://meta.discourse.org/t/96331");
  });

  test("renders nav tabs in yielded <:tabs>", async function (assert) {
    await render(<template>
      <DPageHeader>
        <:tabs>
          <NavItem
            @route="admin.backups.settings"
            @label="settings"
            class="d-backups-tabs__settings"
          />
        </:tabs>
      </DPageHeader>
    </template>);
    assert
      .dom(".d-nav-submenu__tabs .d-backups-tabs__settings")
      .exists()
      .hasText(i18n("settings"));
  });

  test("renders all types of action buttons in yielded <:actions>", async function (assert) {
    let actionCalled = false;
    const someAction = () => {
      actionCalled = true;
    };

    await render(<template>
      <DPageHeader>
        <:actions as |actions|>
          <actions.Primary
            @route="adminBadges.show"
            @routeModels="new"
            @icon="plus"
            @label="admin.badges.new"
            class="new-badge"
          />

          <actions.Default
            @route="adminBadges.award"
            @routeModels="new"
            @icon="upload"
            @label="admin.badges.mass_award.title"
            class="award-badge"
          />

          <actions.Danger
            @action={{someAction}}
            @title="admin.badges.group_settings"
            @label="admin.badges.group_settings"
            @icon="gear"
            class="edit-groupings-btn"
          />
        </:actions>
      </DPageHeader>
    </template>);

    assert
      .dom(
        ".d-page-header__actions .d-page-action-button.new-badge.btn.btn-small.btn-primary"
      )
      .exists();
    assert
      .dom(
        ".d-page-header__actions .d-page-action-button.award-badge.btn.btn-small.btn-default"
      )
      .exists();
    assert
      .dom(
        ".d-page-header__actions .d-page-action-button.edit-groupings-btn.btn.btn-small.btn-danger"
      )
      .exists();

    await click(".edit-groupings-btn");
    assert.true(actionCalled);
  });

  test("@headerActionComponent is rendered with actions arg", async function (assert) {
    await render(<template>
      <DPageHeader @headerActionComponent={{DPageHeaderActionsTestComponent}} />
    </template>);

    assert.dom(".d-page-header-actions-test-component .award-badge").exists();
  });
});

module("Integration | Component | DPageHeader | Mobile", function (hooks) {
  hooks.beforeEach(function () {
    forceMobile();
  });

  setupRenderingTest(hooks);

  test("action buttons become a dropdown on mobile", async function (assert) {
    await render(<template>
      <DPageHeader>
        <:actions as |actions|>
          <actions.Primary
            @route="adminBadges.show"
            @routeModels="new"
            @icon="plus"
            @label="admin.badges.new"
            class="new-badge"
          />

          <actions.Default
            @route="adminBadges.award"
            @routeModels="new"
            @icon="upload"
            @label="admin.badges.mass_award.title"
            class="award-badge"
          />
        </:actions>
      </DPageHeader>
    </template>);

    assert
      .dom(
        ".d-page-header__actions .fk-d-menu__trigger.d-page-header-mobile-actions-trigger"
      )
      .exists();

    await click(".d-page-header-mobile-actions-trigger");

    assert
      .dom(".dropdown-menu.d-page-header__mobile-actions .new-badge")
      .exists();
  });
});
