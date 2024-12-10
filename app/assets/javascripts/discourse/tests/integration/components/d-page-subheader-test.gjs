import { click, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import DPageSubheader from "discourse/components/d-page-subheader";
import { forceMobile } from "discourse/lib/mobile";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { i18n } from "discourse-i18n";

module("Integration | Component | DPageSubheader", function (hooks) {
  setupRenderingTest(hooks);

  test("@titleLabel", async function (assert) {
    await render(<template>
      <DPageSubheader @titleLabel="admin.title" />
    </template>);
    assert
      .dom(".d-page-subheader__title")
      .exists()
      .hasText(i18n("admin.title"));
  });

  test("@titleLabelTranslated", async function (assert) {
    await render(<template>
      <DPageSubheader @titleLabelTranslated="Wow so cool" />
    </template>);
    assert.dom(".d-page-subheader__title").exists().hasText("Wow so cool");
  });

  test("no @descriptionLabel and no @descriptionLabelTranslated", async function (assert) {
    await render(<template><DPageSubheader /></template>);
    assert.dom(".d-page-subheader__description").doesNotExist();
  });

  test("@descriptionLabel", async function (assert) {
    await render(<template>
      <DPageSubheader @descriptionLabel="admin.badges.description" />
    </template>);
    assert
      .dom(".d-page-subheader__description")
      .exists()
      .hasText(i18n("admin.badges.description"));
  });

  test("@descriptionLabelTranslated", async function (assert) {
    await render(<template>
      <DPageSubheader
        @descriptionLabelTranslated="Some description which supports <strong>HTML</strong>"
      />
    </template>);
    assert
      .dom(".d-page-subheader__description")
      .exists()
      .hasText("Some description which supports HTML");
    assert.dom(".d-page-subheader__description strong").exists();
  });

  test("no @learnMoreUrl", async function (assert) {
    await render(<template><DPageSubheader /></template>);
    assert.dom(".d-page-subheader__learn-more").doesNotExist();
  });

  test("@learnMoreUrl", async function (assert) {
    await render(<template>
      <DPageSubheader
        @descriptionLabel="admin.badges.description"
        @learnMoreUrl="https://meta.discourse.org/t/96331"
      />
    </template>);
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

    await render(<template>
      <DPageSubheader>
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
      </DPageSubheader>
    </template>);

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
});

module("Integration | Component | DPageSubheader | Mobile", function (hooks) {
  hooks.beforeEach(function () {
    forceMobile();
  });

  setupRenderingTest(hooks);

  test("action buttons become a dropdown on mobile", async function (assert) {
    await render(<template>
      <DPageSubheader>
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
      </DPageSubheader>
    </template>);

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
