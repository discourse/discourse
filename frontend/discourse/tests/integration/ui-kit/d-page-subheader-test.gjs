import { tracked } from "@glimmer/tracking";
import {
  click,
  find,
  render,
  rerender,
  resetOnerror,
  setupOnerror,
} from "@ember/test-helpers";
import { module, test } from "qunit";
import { forceMobile } from "discourse/lib/mobile";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
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

  test("the title is an h2 by default", async function (assert) {
    await render(<template><DPageSubheader @titleLabel="Title" /></template>);

    assert.dom("h2.d-page-subheader__title").exists();
  });

  test("@titleHeadingLevel picks the heading element", async function (assert) {
    await render(
      <template>
        <DPageSubheader @titleHeadingLevel={{3}} @titleLabel="Title" />
      </template>
    );

    assert.dom("h3.d-page-subheader__title").exists();
    assert
      .dom("h2.d-page-subheader__title")
      .doesNotExist("it does not also render the default level");
  });

  test("a null @titleHeadingLevel falls back to h2", async function (assert) {
    await render(
      <template>
        <DPageSubheader @titleHeadingLevel={{null}} @titleLabel="Title" />
      </template>
    );

    assert.dom("h2.d-page-subheader__title").exists();
  });

  // One test per value: after a render error the app refuses to render again.
  for (const level of [0, 7, -1, 2.5, "3", NaN]) {
    const label = typeof level === "string" ? `"${level}"` : String(level);

    test(`@titleHeadingLevel rejects ${label}`, async function (assert) {
      let raised;
      setupOnerror((error) => (raised = error));

      try {
        await render(
          <template>
            <DPageSubheader @titleHeadingLevel={{level}} @titleLabel="Title" />
          </template>
        );
      } finally {
        resetOnerror();
      }

      assert.true(/must be 1-6/.test(raised?.message));
    });
  }

  test("the title keeps its subheader styling at any heading level", async function (assert) {
    await render(
      <template>
        <DPageSubheader @titleLabel="Default" />
        <DPageSubheader @titleHeadingLevel={{3}} @titleLabel="Nested" />
      </template>
    );

    const h2 = getComputedStyle(find("h2.d-page-subheader__title"));
    const h3 = getComputedStyle(find("h3.d-page-subheader__title"));

    // Pins the stylesheet as loaded: without it both titles would match at
    // browser defaults and the comparisons below would pass vacuously.
    assert.strictEqual(h2.marginBottom, "0px");
    assert.strictEqual(h3.marginBottom, h2.marginBottom, "same margin");
    assert.strictEqual(h3.fontSize, h2.fontSize, "same font size");
  });

  test("the title updates in place and survives level changes", async function (assert) {
    const state = new (class {
      @tracked level = 2;
      @tracked title = "First";
    })();

    await render(
      <template>
        <DPageSubheader
          @titleHeadingLevel={{state.level}}
          @titleLabel={{state.title}}
          @titleUrl="#target"
        />
      </template>
    );

    const heading = find("h2.d-page-subheader__title");
    const link = find(".d-page-subheader__title-link");

    assert
      .dom(heading)
      .doesNotHaveClass("ember-view", "renders no classic component wrapper");

    state.title = "Second";
    await rerender();

    assert.strictEqual(
      find("h2.d-page-subheader__title"),
      heading,
      "keeps the heading node"
    );
    assert.strictEqual(
      find(".d-page-subheader__title-link"),
      link,
      "keeps the link node"
    );
    assert.dom(link).hasText("Second");

    for (const level of [1, 3, 4, 5, 6, 2]) {
      state.level = level;
      await rerender();

      assert.dom(`h${level}.d-page-subheader__title`).exists({ count: 1 });
      assert
        .dom(".d-page-subheader__title-link")
        .hasAttribute("href", "#target", `keeps the link at h${level}`);
    }
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
