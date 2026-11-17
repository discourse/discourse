import { render, triggerEvent } from "@ember/test-helpers";
import { module, test } from "qunit";
import KpiTile from "discourse/admin/components/dashboard/kpi-tile";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

module("Integration | Component | Dashboard | KpiTile", function (hooks) {
  setupRenderingTest(hooks);

  const reportQuery = { start_date: "2026-04-01", end_date: "2026-04-30" };

  test("renders the label and formatted value", async function (assert) {
    await render(
      <template>
        <KpiTile
          @reportQuery={{reportQuery}}
          @reportType="signups"
          @type="new_signups"
          @value={{1100}}
        />
      </template>
    );

    assert.dom(".db-kpi__value").hasText("1,100");
    assert.dom(".db-kpi__label").includesText("New sign-ups");
  });

  test("formats percentage KPIs with a percent suffix and 1 decimal", async function (assert) {
    await render(
      <template>
        <KpiTile
          @reportQuery={{reportQuery}}
          @reportType="dau_by_mau"
          @type="dau_mau"
          @value={{21.6}}
        />
      </template>
    );

    assert.dom(".db-kpi__value").hasText("21.6%");
    assert.dom(".db-kpi__label").includesText("DAU / MAU stickiness");
  });

  test("renders an em dash when the value is null", async function (assert) {
    await render(
      <template>
        <KpiTile
          @reportQuery={{reportQuery}}
          @reportType="signups"
          @type="new_signups"
          @value={{null}}
        />
      </template>
    );

    assert.dom(".db-kpi__value").hasText("—");
  });

  test("hides the delta when percentChange is null", async function (assert) {
    await render(
      <template>
        <KpiTile
          @percentChange={{null}}
          @reportQuery={{reportQuery}}
          @reportType="signups"
          @type="new_signups"
          @value={{1100}}
        />
      </template>
    );

    assert.dom(".db-delta").doesNotExist();
  });

  test("renders the positive delta with --pos class", async function (assert) {
    await render(
      <template>
        <KpiTile
          @percentChange={{12.02}}
          @reportQuery={{reportQuery}}
          @reportType="signups"
          @type="new_signups"
          @value={{1100}}
        />
      </template>
    );

    assert.dom(".db-delta").hasClass("--pos");
    assert.dom(".db-delta").hasText("+12%");
  });

  test("renders sub-1% positive deltas with one decimal", async function (assert) {
    await render(
      <template>
        <KpiTile
          @percentChange={{0.4}}
          @reportQuery={{reportQuery}}
          @reportType="signups"
          @type="new_signups"
          @value={{1100}}
        />
      </template>
    );

    assert.dom(".db-delta").hasClass("--pos");
    assert.dom(".db-delta").hasText("+0.4%");
  });

  test("renders sub-1% negative deltas with one decimal and a minus sign", async function (assert) {
    await render(
      <template>
        <KpiTile
          @percentChange={{-0.4}}
          @reportQuery={{reportQuery}}
          @reportType="signups"
          @type="new_signups"
          @value={{1100}}
        />
      </template>
    );

    assert.dom(".db-delta").hasClass("--neg");
    assert.dom(".db-delta").hasText("-0.4%");
  });

  test("renders exact zero deltas without a sign", async function (assert) {
    await render(
      <template>
        <KpiTile
          @percentChange={{0}}
          @reportQuery={{reportQuery}}
          @reportType="signups"
          @type="new_signups"
          @value={{1100}}
        />
      </template>
    );

    assert.dom(".db-delta").hasText("0%");
  });

  test("renders the negative delta with --neg class", async function (assert) {
    await render(
      <template>
        <KpiTile
          @percentChange={{-38.5}}
          @reportQuery={{reportQuery}}
          @reportType="signups"
          @type="new_signups"
          @value={{142}}
        />
      </template>
    );

    assert.dom(".db-delta").hasClass("--neg");
    assert.dom(".db-delta").hasText("-38%");
  });

  test("links to the report route with the report query params", async function (assert) {
    await render(
      <template>
        <KpiTile
          @reportQuery={{reportQuery}}
          @reportType="signups"
          @type="new_signups"
          @value={{1100}}
        />
      </template>
    );

    const href = document.querySelector("a.db-kpi").getAttribute("href");
    assert.true(
      href.includes("/admin/reports/signups"),
      "links to the report route"
    );
    assert.true(
      href.includes("start_date=2026-04-01"),
      "carries the start_date query param"
    );
    assert.true(
      href.includes("end_date=2026-04-30"),
      "carries the end_date query param"
    );
  });

  test("includes the trend in the aria-label", async function (assert) {
    await render(
      <template>
        <KpiTile
          @percentChange={{12}}
          @reportQuery={{reportQuery}}
          @reportType="signups"
          @type="new_signups"
          @value={{1100}}
        />
      </template>
    );

    assert
      .dom("a.db-kpi")
      .hasAttribute("aria-label", "New sign-ups, 1,100, +12%");
  });

  test("renders an accessible tooltip with the KPI description", async function (assert) {
    await render(
      <template>
        <KpiTile
          @reportQuery={{reportQuery}}
          @reportType="signups"
          @type="new_signups"
          @value={{1100}}
        />
      </template>
    );

    assert.dom(".db-kpi__tooltip").exists();
    await triggerEvent(".db-kpi__tooltip", "pointermove");
    assert
      .dom(".fk-d-tooltip__content")
      .includesText(
        "Accounts created, including unactivated and staged accounts."
      );
  });

  test("appends the comparison label to the trend in aria-label", async function (assert) {
    await render(
      <template>
        <KpiTile
          @comparisonLabel="vs last 30 days"
          @percentChange={{12}}
          @reportQuery={{reportQuery}}
          @reportType="signups"
          @type="new_signups"
          @value={{1100}}
        />
      </template>
    );

    assert
      .dom("a.db-kpi")
      .hasAttribute("aria-label", "New sign-ups, 1,100, +12% vs last 30 days");
  });
});
