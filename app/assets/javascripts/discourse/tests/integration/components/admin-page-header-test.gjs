import { click, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import DBreadcrumbsItem from "discourse/components/d-breadcrumbs-item";
import NavItem from "discourse/components/nav-item";
import { forceMobile } from "discourse/lib/mobile";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { i18n } from "discourse-i18n";
import AdminPageHeader from "admin/components/admin-page-header";

const AdminPageHeaderActionsTestComponent = <template>
  <div class="admin-page-header-actions-test-component">
    <@actions.Default
      @route="adminBadges.award"
      @routeModels="new"
      @icon="upload"
      @label="admin.badges.mass_award.title"
      class="award-badge"
    />
  </div>
</template>;

module("Integration | Component | AdminPageHeader", function (hooks) {
  setupRenderingTest(hooks);

  test("no @titleLabel or @titleLabelTranslated", async function (assert) {
    await render(<template><AdminPageHeader /></template>);
    assert.dom(".admin-page-header__title").doesNotExist();
  });

  test("@titleLabel", async function (assert) {
    await render(<template>
      <AdminPageHeader @titleLabel="admin.title" />
    </template>);
    assert
      .dom(".admin-page-header__title")
      .exists()
      .hasText(i18n("admin.title"));
  });

  test("@titleLabelTranslated", async function (assert) {
    await render(<template>
      <AdminPageHeader @titleLabelTranslated="Wow so cool" />
    </template>);
    assert.dom(".admin-page-header__title").exists().hasText("Wow so cool");
  });

  test("@shouldDisplay", async function (assert) {
    await render(<template>
      <AdminPageHeader
        @titleLabelTranslated="Wow so cool"
        @shouldDisplay={{false}}
      />
    </template>);
    assert.dom(".admin-page-header").doesNotExist();
  });

  test("renders base breadcrumbs and yielded <:breadcrumbs>", async function (assert) {
    await render(<template>
      <AdminPageHeader @titleLabel="admin.titile">
        <:breadcrumbs>
          <DBreadcrumbsItem
            @path="/admin/badges"
            @label={{i18n "admin.badges.title"}}
          />
        </:breadcrumbs>
      </AdminPageHeader>
    </template>);

    assert
      .dom(".admin-page-header__breadcrumbs .d-breadcrumbs__item")
      .exists({ count: 2 });
    assert
      .dom(".admin-page-header__breadcrumbs .d-breadcrumbs__item")
      .hasText(i18n("admin_title"));
    assert
      .dom(".admin-page-header__breadcrumbs .d-breadcrumbs__item:last-child")
      .hasText(i18n("admin.badges.title"));
  });

  test("no @descriptionLabel and no @descriptionLabelTranslated", async function (assert) {
    await render(<template><AdminPageHeader /></template>);
    assert.dom(".admin-page-header__description").doesNotExist();
  });

  test("@descriptionLabel", async function (assert) {
    await render(<template>
      <AdminPageHeader @descriptionLabel="admin.badges.description" />
    </template>);
    assert
      .dom(".admin-page-header__description")
      .exists()
      .hasText(i18n("admin.badges.description"));
  });

  test("@descriptionLabelTranslated", async function (assert) {
    await render(<template>
      <AdminPageHeader
        @descriptionLabelTranslated="Some description which supports <strong>HTML</strong>"
      />
    </template>);
    assert
      .dom(".admin-page-header__description")
      .exists()
      .hasText("Some description which supports HTML");
    assert.dom(".admin-page-header__description strong").exists();
  });

  test("no @learnMoreUrl", async function (assert) {
    await render(<template><AdminPageHeader /></template>);
    assert.dom(".admin-page-header__learn-more").doesNotExist();
  });

  test("@learnMoreUrl", async function (assert) {
    await render(<template>
      <AdminPageHeader
        @descriptionLabel="admin.badges.description"
        @learnMoreUrl="https://meta.discourse.org/t/96331"
      />
    </template>);
    assert.dom(".admin-page-header__learn-more").exists();
    assert
      .dom(".admin-page-header__learn-more a")
      .hasText("Learn more…")
      .hasAttribute("href", "https://meta.discourse.org/t/96331");
  });

  test("renders nav tabs in yielded <:tabs>", async function (assert) {
    await render(<template>
      <AdminPageHeader>
        <:tabs>
          <NavItem
            @route="admin.backups.settings"
            @label="settings"
            class="admin-backups-tabs__settings"
          />
        </:tabs>
      </AdminPageHeader>
    </template>);
    assert
      .dom(".admin-nav-submenu__tabs .admin-backups-tabs__settings")
      .exists()
      .hasText(i18n("settings"));
  });

  test("renders all types of action buttons in yielded <:actions>", async function (assert) {
    let actionCalled = false;
    const someAction = () => {
      actionCalled = true;
    };

    await render(<template>
      <AdminPageHeader>
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
      </AdminPageHeader>
    </template>);

    assert
      .dom(
        ".admin-page-header__actions .admin-page-action-button.new-badge.btn.btn-small.btn-primary"
      )
      .exists();
    assert
      .dom(
        ".admin-page-header__actions .admin-page-action-button.award-badge.btn.btn-small.btn-default"
      )
      .exists();
    assert
      .dom(
        ".admin-page-header__actions .admin-page-action-button.edit-groupings-btn.btn.btn-small.btn-danger"
      )
      .exists();

    await click(".edit-groupings-btn");
    assert.true(actionCalled);
  });

  test("@headerActionComponent is rendered with actions arg", async function (assert) {
    await render(<template>
      <AdminPageHeader
        @headerActionComponent={{AdminPageHeaderActionsTestComponent}}
      />
    </template>);

    assert
      .dom(".admin-page-header-actions-test-component .award-badge")
      .exists();
  });
});

module("Integration | Component | AdminPageHeader | Mobile", function (hooks) {
  hooks.beforeEach(function () {
    forceMobile();
  });

  setupRenderingTest(hooks);

  test("action buttons become a dropdown on mobile", async function (assert) {
    await render(<template>
      <AdminPageHeader>
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
      </AdminPageHeader>
    </template>);

    assert
      .dom(
        ".admin-page-header__actions .fk-d-menu__trigger.admin-page-header-mobile-actions-trigger"
      )
      .exists();

    await click(".admin-page-header-mobile-actions-trigger");

    assert
      .dom(".dropdown-menu.admin-page-header__mobile-actions .new-badge")
      .exists();
  });
});
