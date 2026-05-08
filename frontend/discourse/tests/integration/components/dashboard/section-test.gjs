import { click, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import DashboardSection from "discourse/admin/components/dashboard/section";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

module("Integration | Component | Dashboard | Section", function (hooks) {
  setupRenderingTest(hooks);

  test("renders the @title in the section header", async function (assert) {
    await render(
      <template>
        <DashboardSection @title="Reports">content</DashboardSection>
      </template>
    );

    assert.dom(".db-section__header").hasText("Reports");
  });

  test("renders @description when provided", async function (assert) {
    await render(
      <template>
        <DashboardSection @title="Reports" @description="Last 30 days">
          content
        </DashboardSection>
      </template>
    );

    assert.dom(".db-section__intro").hasText("Last 30 days");
  });

  test("omits the description node when @description is missing", async function (assert) {
    await render(
      <template>
        <DashboardSection @title="Reports">content</DashboardSection>
      </template>
    );

    assert.dom(".db-section__intro").doesNotExist();
  });

  test("yields content into the wrapper", async function (assert) {
    await render(
      <template>
        <DashboardSection @title="Reports">
          <span class="my-child">hello</span>
        </DashboardSection>
      </template>
    );

    assert.dom(".db-section__wrapper .my-child").hasText("hello");
  });

  test("yields startDate and endDate to the default block", async function (assert) {
    const startDate = "2026-01-01";
    const endDate = "2026-01-31";

    await render(
      <template>
        <DashboardSection
          @title="Reports"
          @startDate={{startDate}}
          @endDate={{endDate}}
        >
          <:default as |section|>
            <span class="start">{{section.startDate}}</span>
            <span class="end">{{section.endDate}}</span>
          </:default>
        </DashboardSection>
      </template>
    );

    assert.dom(".start").hasText("2026-01-01");
    assert.dom(".end").hasText("2026-01-31");
  });

  test("renders the wrapper with a border by default", async function (assert) {
    await render(
      <template>
        <DashboardSection @title="Reports">content</DashboardSection>
      </template>
    );

    assert.dom(".db-section__wrapper").doesNotHaveClass("--no-border");
  });

  test("adds --no-border modifier when @bordered is false", async function (assert) {
    await render(
      <template>
        <DashboardSection @title="Reports" @bordered={{false}}>
          content
        </DashboardSection>
      </template>
    );

    assert.dom(".db-section__wrapper").hasClass("--no-border");
  });

  test("uses --column layout by default", async function (assert) {
    await render(
      <template>
        <DashboardSection @title="Reports">content</DashboardSection>
      </template>
    );

    assert.dom(".db-section__wrapper").hasClass("--column");
  });

  test("applies the @layout modifier when set", async function (assert) {
    await render(
      <template>
        <DashboardSection @title="Reports" @layout="grid">
          content
        </DashboardSection>
      </template>
    );

    assert.dom(".db-section__wrapper").hasClass("--grid");
    assert.dom(".db-section__wrapper").doesNotHaveClass("--column");
  });

  test("falls back to --column when @layout is unrecognized", async function (assert) {
    await render(
      <template>
        <DashboardSection @title="Reports" @layout="bogus">
          content
        </DashboardSection>
      </template>
    );

    assert.dom(".db-section__wrapper").hasClass("--column");
  });

  test("does not render a header action when @headerActionIcon is missing", async function (assert) {
    await render(
      <template>
        <DashboardSection @title="Reports">content</DashboardSection>
      </template>
    );

    assert.dom(".db-section__header-action").doesNotExist();
  });

  test("renders a header action button when @headerActionIcon is set", async function (assert) {
    await render(
      <template>
        <DashboardSection @title="Reports" @headerActionIcon="gear">
          content
        </DashboardSection>
      </template>
    );

    assert.dom(".db-section__header-action button").exists();
    assert.dom(".db-section__header-action .d-icon-gear").exists();
  });

  test("invokes @headerAction when the header action button is clicked", async function (assert) {
    let called = false;
    const handler = () => (called = true);

    await render(
      <template>
        <DashboardSection
          @title="Reports"
          @headerActionIcon="gear"
          @headerAction={{handler}}
        >
          content
        </DashboardSection>
      </template>
    );

    await click(".db-section__header-action button");
    assert.true(called);
  });
});
