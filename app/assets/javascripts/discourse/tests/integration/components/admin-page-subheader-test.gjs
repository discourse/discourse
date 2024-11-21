import { click, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { forceMobile } from "discourse/lib/mobile";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { i18n } from "discourse-i18n";
import AdminPageSubheader from "admin/components/admin-page-subheader";

module("Integration | Component | AdminPageSubheader", function (hooks) {
  setupRenderingTest(hooks);

  test("@titleLabel", async function (assert) {
    await render(<template>
      <AdminPageSubheader @titleLabel="admin.title" />
    </template>);
    assert
      .dom(".admin-page-subheader__title")
      .exists()
      .hasText(i18n("admin.title"));
  });

  test("@titleLabelTranslated", async function (assert) {
    await render(<template>
      <AdminPageSubheader @titleLabelTranslated="Wow so cool" />
    </template>);
    assert.dom(".admin-page-subheader__title").exists().hasText("Wow so cool");
  });

  test("no @descriptionLabel and no @descriptionLabelTranslated", async function (assert) {
    await render(<template><AdminPageSubheader /></template>);
    assert.dom(".admin-page-subheader__description").doesNotExist();
  });

  test("@descriptionLabel", async function (assert) {
    await render(<template>
      <AdminPageSubheader @descriptionLabel="admin.badges.description" />
    </template>);
    assert
      .dom(".admin-page-subheader__description")
      .exists()
      .hasText(i18n("admin.badges.description"));
  });

  test("@descriptionLabelTranslated", async function (assert) {
    await render(<template>
      <AdminPageSubheader
        @descriptionLabelTranslated="Some description which supports <strong>HTML</strong>"
      />
    </template>);
    assert
      .dom(".admin-page-subheader__description")
      .exists()
      .hasText("Some description which supports HTML");
    assert.dom(".admin-page-subheader__description strong").exists();
  });

  test("no @learnMoreUrl", async function (assert) {
    await render(<template><AdminPageSubheader /></template>);
    assert.dom(".admin-page-subheader__learn-more").doesNotExist();
  });

  test("@learnMoreUrl", async function (assert) {
    await render(<template>
      <AdminPageSubheader
        @descriptionLabel="admin.badges.description"
        @learnMoreUrl="https://meta.discourse.org/t/96331"
      />
    </template>);
    assert.dom(".admin-page-subheader__learn-more").exists();
    assert
      .dom(".admin-page-subheader__learn-more a")
      .hasText("Learn more…")
      .hasAttribute("href", "https://meta.discourse.org/t/96331");
  });

  test("renders all types of action buttons in yielded <:actions>", async function (assert) {
    let actionCalled = false;
    const someAction = () => {
      actionCalled = true;
    };

    await render(<template>
      <AdminPageSubheader>
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
      </AdminPageSubheader>
    </template>);

    assert
      .dom(
        ".admin-page-subheader__actions .admin-page-action-button.new-badge.btn.btn-small.btn-primary"
      )
      .exists();
    assert
      .dom(
        ".admin-page-subheader__actions .admin-page-action-button.award-badge.btn.btn-small.btn-default"
      )
      .exists();
    assert
      .dom(
        ".admin-page-subheader__actions .admin-page-action-button.edit-groupings-btn.btn.btn-small.btn-danger"
      )
      .exists();

    await click(".edit-groupings-btn");
    assert.true(actionCalled);
  });
});

module(
  "Integration | Component | AdminPageSubheader | Mobile",
  function (hooks) {
    hooks.beforeEach(function () {
      forceMobile();
    });

    setupRenderingTest(hooks);

    test("action buttons become a dropdown on mobile", async function (assert) {
      await render(<template>
        <AdminPageSubheader>
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
        </AdminPageSubheader>
      </template>);

      assert
        .dom(
          ".admin-page-subheader .fk-d-menu__trigger.admin-page-subheader-mobile-actions-trigger"
        )
        .exists();

      await click(".admin-page-subheader-mobile-actions-trigger");

      assert
        .dom(".dropdown-menu.admin-page-subheader__mobile-actions .new-badge")
        .exists();
    });
  }
);
