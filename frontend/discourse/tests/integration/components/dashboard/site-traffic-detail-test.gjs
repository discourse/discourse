import { tracked } from "@glimmer/tracking";
import {
  clearRender,
  click,
  render,
  settled,
  triggerKeyEvent,
} from "@ember/test-helpers";
import { module, test } from "qunit";
import sinon from "sinon";
import SiteTrafficDetail from "discourse/admin/components/dashboard/site-traffic-detail";
import SiteTrafficBreakdownModal from "discourse/admin/components/modal/site-traffic-breakdown";
import DiscourseURL from "discourse/lib/url";
import Session from "discourse/models/session";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

class DateState {
  @tracked startDate = "2026-05-01";
  @tracked endDate = "2026-05-12";
}

function payload({
  pageviews = 5,
  filters = {},
  countries = [],
  browsers = [],
  topUrls = [],
  analysis = {},
} = {}) {
  return {
    analysis: {
      requested_start_date: "2026-05-01",
      requested_end_date: "2026-05-12",
      available_start_at: "2026-05-01T10:00:00Z",
      available_end_at: "2026-05-12T10:00:00Z",
      analyzed_start_at: "2026-05-01T10:00:00Z",
      analyzed_end_at: "2026-05-12T10:00:00Z",
      analyzed_event_count: pageviews,
      event_cap: 1_000_000,
      retention_truncated: false,
      cap_truncated: false,
      crawler_scoring_state: "disabled",
      ...analysis,
    },
    filters,
    summary: {
      pageviews,
      logged_in_human_pageviews: 0,
      anonymous_human_pageviews: pageviews,
      likely_crawler_pageviews: 0,
      distinct_sessions: 3,
      bounce_rate: 67,
      average_session_duration_seconds: 20,
    },
    series: [
      {
        date: "2026-05-10",
        pageviews,
        logged_in_human_pageviews: 0,
        anonymous_human_pageviews: pageviews,
        likely_crawler_pageviews: 0,
      },
    ],
    dimensions: {
      top_urls: topUrls,
      entry_urls: [],
      traffic_sources: [],
      countries,
      networks: [],
      browsers,
      ip_addresses: [],
    },
  };
}

function response(body, status = 200) {
  return {
    ok: status >= 200 && status < 300,
    status,
    json: async () => body,
  };
}

function deferredRequest(options) {
  let resolve;
  let reject;
  const promise = new Promise((promiseResolve, promiseReject) => {
    resolve = promiseResolve;
    reject = promiseReject;
  });
  const request = { promise, resolve, aborted: false };

  options.signal.addEventListener("abort", () => {
    request.aborted = true;
    reject(new DOMException("Superseded", "AbortError"));
  });

  return request;
}

module(
  "Integration | Component | Dashboard | Site traffic detail",
  function (hooks) {
    setupRenderingTest(hooks);

    hooks.beforeEach(function () {
      this.currentUser.setProperties({ id: 42, admin: true });
      this.state = new DateState();
      this.setPeriod = () => {};
      this.setCustomDateRange = () => {};
      Session.currentProp("csrfToken", "traffic-csrf");
      this.fetchStub = sinon.stub(window, "fetch");
      sessionStorage.clear();
      window.location.hash = "";
    });

    hooks.afterEach(function () {
      window.location.hash = "";
    });

    test("posts the closed request contract with CSRF credentials", async function (assert) {
      this.fetchStub.resolves(response(payload()));

      await render(
        <template>
          <SiteTrafficDetail
            @startDate={{this.state.startDate}}
            @endDate={{this.state.endDate}}
            @startDateValue={{this.state.startDate}}
            @endDateValue={{this.state.endDate}}
            @setPeriod={{this.setPeriod}}
            @setCustomDateRange={{this.setCustomDateRange}}
          />
        </template>
      );

      assert.strictEqual(this.fetchStub.callCount, 1);
      const [url, options] = this.fetchStub.firstCall.args;
      assert.true(url.endsWith("/admin/dashboard/traffic.json"));
      assert.strictEqual(options.method, "POST");
      assert.strictEqual(options.credentials, "same-origin");
      assert.strictEqual(options.headers["X-CSRF-Token"], "traffic-csrf");
      assert.deepEqual(JSON.parse(options.body), {
        start_date: "2026-05-01",
        end_date: "2026-05-12",
        filters: {},
      });
      assert.dom("[data-test-metric]").includesText("Pageviews");
      assert.dom("[data-test-metric]").includesText("5");
    });

    test("keeps the last success and only accepts the newest request", async function (assert) {
      const requests = [];
      this.fetchStub.callsFake((_url, options) => {
        const request = deferredRequest(options);
        requests.push(request);
        return request.promise;
      });

      await render(
        <template>
          <SiteTrafficDetail
            @startDate={{this.state.startDate}}
            @endDate={{this.state.endDate}}
            @startDateValue={{this.state.startDate}}
            @endDateValue={{this.state.endDate}}
          />
        </template>
      );

      requests[0].resolve(
        response(
          payload({
            countries: [
              {
                value: "US",
                label: "US",
                pageviews: 3,
                filterable: true,
              },
            ],
            browsers: [
              {
                value: "firefox",
                label: "firefox",
                pageviews: 1,
                filterable: true,
              },
            ],
          })
        )
      );
      await settled();

      await click(
        "[data-test-breakdown='countries'] [data-test-breakdown-row]"
      );
      assert.dom("[data-test-traffic-loading]").exists();
      assert.dom("[data-test-metric]").includesText("5");

      await click("[data-test-breakdown='browsers'] [data-test-breakdown-row]");
      assert.true(requests[1].aborted, "the superseded request was aborted");

      requests[2].resolve(response(payload({ pageviews: 1 })));
      await settled();

      assert.dom("[data-test-metric]").includesText("1");
      assert.dom("[data-test-traffic-loading]").doesNotExist();
    });

    test("aborts outstanding work when destroyed", async function (assert) {
      let request;
      this.fetchStub.callsFake((_url, options) => {
        request = deferredRequest(options);
        return request.promise;
      });

      await render(
        <template>
          <SiteTrafficDetail
            @startDate={{this.state.startDate}}
            @endDate={{this.state.endDate}}
          />
        </template>
      );
      await clearRender();

      assert.true(request.aborted);
    });

    test("shares safe filters but keeps paths in session storage", async function (assert) {
      sinon.stub(DiscourseURL, "replaceState");
      this.fetchStub.resolves(
        response(
          payload({
            countries: [
              {
                value: "US",
                label: "US",
                pageviews: 3,
                filterable: true,
              },
            ],
            topUrls: [
              {
                value: "/top",
                label: "/top",
                pageviews: 2,
                filterable: true,
              },
            ],
          })
        )
      );

      await render(
        <template>
          <SiteTrafficDetail
            @startDate={{this.state.startDate}}
            @endDate={{this.state.endDate}}
            @startDateValue={{this.state.startDate}}
            @endDateValue={{this.state.endDate}}
          />
        </template>
      );

      await click("[data-test-breakdown='pages'] [data-test-breakdown-row]");
      const sensitiveState = Array.from(
        { length: sessionStorage.length },
        (_value, index) => sessionStorage.getItem(sessionStorage.key(index))
      ).join(" ");
      assert.true(sensitiveState.includes("/top"));
      assert.false(
        DiscourseURL.replaceState.lastCall.args[0].includes("/top"),
        "the path is absent from browser history"
      );

      await click(
        "[data-test-breakdown='countries'] [data-test-breakdown-row]"
      );
      assert.true(
        DiscourseURL.replaceState.lastCall.args[0].includes("#country=US")
      );
    });

    test("renders timeout, invalid, rate-limited, and retry states distinctly", async function (assert) {
      this.fetchStub
        .onCall(0)
        .resolves(response({ error_type: "timeout", retryable: true }, 503));
      this.fetchStub.onCall(1).resolves(response(payload({ pageviews: 0 })));

      await render(
        <template>
          <SiteTrafficDetail
            @startDate={{this.state.startDate}}
            @endDate={{this.state.endDate}}
            @startDateValue={{this.state.startDate}}
            @endDateValue={{this.state.endDate}}
          />
        </template>
      );

      assert.dom("[role='alert']").includesText("too long");
      assert.dom("[role='alert'] button").exists({ count: 2 });

      await click("[role='alert'] button");
      assert.dom("[role='status']").includesText("No matching pageviews");

      this.fetchStub.resolves(response({ error_type: "rate_limited" }, 429));
      this.state.startDate = "2026-05-02";
      await settled();
      assert.dom("[role='alert']").includesText("too many");
      assert.dom("[role='alert'] button").doesNotExist();

      this.fetchStub.resolves(response({ error_type: "invalid_request" }, 400));
      this.state.startDate = "2026-05-03";
      await settled();
      assert.dom("[role='alert']").includesText("invalid");
    });

    test("provides keyboard-operable Pages tabs", async function (assert) {
      this.fetchStub.resolves(response(payload()));

      await render(
        <template>
          <SiteTrafficDetail
            @startDate={{this.state.startDate}}
            @endDate={{this.state.endDate}}
            @startDateValue={{this.state.startDate}}
            @endDateValue={{this.state.endDate}}
          />
        </template>
      );

      const topTab = document.querySelector("#site-traffic-tab-top-urls");
      topTab.focus();
      await triggerKeyEvent(topTab, "keydown", "ArrowRight");

      assert
        .dom("#site-traffic-tab-entry-urls")
        .hasAttribute("aria-selected", "true");
      assert.strictEqual(
        document.activeElement.id,
        "site-traffic-tab-entry-urls"
      );
      assert
        .dom("#site-traffic-pages-panel")
        .hasAttribute("aria-labelledby", "site-traffic-tab-entry-urls");
    });
  }
);

module(
  "Integration | Component | Modal | Site traffic breakdown",
  function (hooks) {
    setupRenderingTest(hooks);

    test("renders a semantic table capped at fifty rows", async function (assert) {
      let selected;
      this.model = {
        title: "Top URLs",
        rows: Array.from({ length: 55 }, (_value, index) => ({
          value: `/page-${index}`,
          displayLabel: `/page-${index}`,
          formattedPageviews: `${55 - index}`,
          filterable: true,
        })),
        onSelect: (row) => {
          selected = row.value;
        },
      };
      this.closeModal = () => {};

      await render(
        <template>
          <SiteTrafficBreakdownModal
            @model={{this.model}}
            @closeModal={{this.closeModal}}
          />
        </template>
      );

      assert.dom("table[aria-label='Top URLs'] thead th").exists({ count: 2 });
      assert.dom("table[aria-label='Top URLs'] tbody tr").exists({ count: 50 });

      await click("tbody [data-test-breakdown-row]");
      assert.strictEqual(selected, "/page-0");
    });
  }
);
