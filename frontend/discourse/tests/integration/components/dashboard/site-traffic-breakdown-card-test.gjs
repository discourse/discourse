import { tracked } from "@glimmer/tracking";
import { click, find, render, triggerKeyEvent } from "@ember/test-helpers";
import { module, test } from "qunit";
import SiteTrafficBreakdownCard from "discourse/admin/components/dashboard/site-traffic-breakdown-card";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

class CardState {
  @tracked activeTab = "traffic_sources";
  @tracked filterDimension = "referrer";
  @tracked rows = Array.from({ length: 9 }, (_value, index) => ({
    value: `source-${index}.example`,
    displayLabel: `source-${index}.example`,
    formattedPageviews: `${9 - index}`,
    filterable: true,
  }));

  tabs = [
    { key: "traffic_sources", label: "Referrers" },
    { key: "countries", label: "Countries" },
    { key: "networks", label: "Networks" },
  ];
}

module(
  "Integration | Component | Dashboard | SiteTrafficBreakdownCard",
  function (hooks) {
    setupRenderingTest(hooks);

    test("supports shared filtering, view more, and tab keyboard movement", async function (assert) {
      this.state = new CardState();
      this.appliedFilter = null;
      this.viewMore = null;
      this.selectTab = (tabKey) => {
        this.state.activeTab = tabKey;
      };
      this.applyFilter = (dimension, value) => {
        this.appliedFilter = { dimension, value };
      };
      this.showMore = (dimension, title, rows) => {
        this.viewMore = { dimension, title, rows };
      };

      await render(
        <template>
          <SiteTrafficBreakdownCard
            @cardKey="sources"
            @title="Sources"
            @tabs={{this.state.tabs}}
            @activeTab={{this.state.activeTab}}
            @rows={{this.state.rows}}
            @filterDimension="referrer"
            @onSelectTab={{this.selectTab}}
            @onApplyFilter={{this.applyFilter}}
            @onViewMore={{this.showMore}}
          />
        </template>
      );

      assert
        .dom("[data-test-breakdown='sources'].site-traffic-detail__card")
        .exists("the component renders the shared card root");
      assert
        .dom("[data-test-breakdown-row]")
        .exists({ count: 8 }, "the compact list is capped at eight rows");

      await click("button[data-test-breakdown-row]");
      assert.deepEqual(
        this.appliedFilter,
        { dimension: "referrer", value: "source-0.example" },
        "a standard row applies the supplied exact filter"
      );

      await click(".site-traffic-detail__view-more");
      assert.strictEqual(
        this.viewMore.dimension,
        "traffic_sources",
        "View more passes the active dimension"
      );
      assert.strictEqual(
        this.viewMore.title,
        "Referrers",
        "View more passes the active tab label"
      );
      assert.strictEqual(
        this.viewMore.rows,
        this.state.rows,
        "View more passes every formatted row"
      );

      const referrersTab = find("#site-traffic-sources-tab-traffic_sources");
      referrersTab.focus();
      await triggerKeyEvent(referrersTab, "keydown", "ArrowRight");
      assert.strictEqual(
        this.state.activeTab,
        "countries",
        "ArrowRight selects the next tab"
      );
      assert.strictEqual(
        document.activeElement.id,
        "site-traffic-sources-tab-countries",
        "ArrowRight focuses the selected tab"
      );

      await triggerKeyEvent(
        "#site-traffic-sources-tab-countries",
        "keydown",
        "End"
      );
      assert.strictEqual(
        this.state.activeTab,
        "networks",
        "End selects the final tab"
      );

      await triggerKeyEvent(
        "#site-traffic-sources-tab-networks",
        "keydown",
        "Home"
      );
      assert.strictEqual(
        this.state.activeTab,
        "traffic_sources",
        "Home selects the first tab"
      );

      await triggerKeyEvent(
        "#site-traffic-sources-tab-traffic_sources",
        "keydown",
        "ArrowLeft"
      );
      assert.strictEqual(
        this.state.activeTab,
        "networks",
        "ArrowLeft wraps to the final tab"
      );
    });

    test("uses link and sibling filter actions for URL tabs", async function (assert) {
      this.state = new CardState();
      this.state.activeTab = "top_urls";
      this.state.filterDimension = "top_url";
      this.state.tabs = [
        { key: "top_urls", label: "Top URLs" },
        { key: "entry_urls", label: "Entry URLs" },
      ];
      this.urlRows = {
        top_urls: [
          {
            value: "/latest",
            displayLabel: "/latest",
            formattedPageviews: "3",
            filterable: true,
          },
          {
            value: "/about",
            displayLabel: "/about",
            formattedPageviews: "2",
            filterable: false,
          },
        ],
        entry_urls: [
          {
            value: "/privacy",
            displayLabel: "/privacy",
            formattedPageviews: "4",
            filterable: true,
          },
        ],
      };
      this.state.rows = this.urlRows.top_urls;
      this.appliedFilter = null;
      this.selectTab = (tabKey) => {
        this.state.activeTab = tabKey;
        this.state.filterDimension =
          tabKey === "top_urls" ? "top_url" : "entry_url";
        this.state.rows = this.urlRows[tabKey];
      };
      this.applyFilter = (dimension, value) => {
        this.appliedFilter = { dimension, value };
      };
      this.showMore = () => {};

      await render(
        <template>
          <SiteTrafficBreakdownCard
            @cardKey="pages"
            @title="Pages"
            @tabs={{this.state.tabs}}
            @activeTab={{this.state.activeTab}}
            @rows={{this.state.rows}}
            @filterDimension={{this.state.filterDimension}}
            @onSelectTab={{this.selectTab}}
            @onApplyFilter={{this.applyFilter}}
            @onViewMore={{this.showMore}}
          />
        </template>
      );

      assert
        .dom("[data-test-url-link][href='/latest']")
        .hasAttribute("href", "/latest", "the Top URL text is a real link");
      assert
        .dom(
          "[data-test-url-link][href='/latest'] + [data-test-url-filter-area]"
        )
        .hasAttribute(
          "aria-label",
          "Filter by /latest",
          "the Top URL has a sibling filter action"
        );
      assert
        .dom("[data-test-url-filter-area] .site-traffic-detail__row-count")
        .hasText("3", "the Top URL filter action contains its count");
      assert
        .dom("a[data-test-url-link][href='/about']")
        .hasAttribute(
          "href",
          "/about",
          "a safe nonfilterable URL remains a link"
        );
      assert
        .dom(
          "a[data-test-url-link][href='/about'] + [data-test-url-filter-area]"
        )
        .doesNotExist("a nonfilterable URL has no filter action");
      assert
        .dom("[data-test-breakdown='pages'] .d-icon-filter")
        .doesNotExist("the Top URL row has no filter icon");

      await click("[data-test-url-filter-area]");
      assert.deepEqual(
        this.appliedFilter,
        { dimension: "top_url", value: "/latest" },
        "the Top URL action applies the exact filter"
      );

      await click("[data-site-traffic-breakdown-tab='entry_urls']");

      assert
        .dom("[data-test-url-link][href='/privacy']")
        .hasAttribute(
          "href",
          "/privacy",
          "the Entry URL text uses the same link markup"
        );
      assert
        .dom(
          "[data-test-url-link][href='/privacy'] + [data-test-url-filter-area]"
        )
        .hasAttribute(
          "title",
          "Filter by /privacy",
          "the Entry URL uses the same sibling filter action"
        );
      assert
        .dom("[data-test-url-filter-area] .site-traffic-detail__row-count")
        .hasText("4", "the Entry URL filter action contains its count");
      assert
        .dom("[data-test-breakdown='pages'] .d-icon-filter")
        .doesNotExist("the Entry URL row has no filter icon");

      await click("[data-test-url-filter-area]");
      assert.deepEqual(
        this.appliedFilter,
        { dimension: "entry_url", value: "/privacy" },
        "the Entry URL action applies the exact filter"
      );
    });
  }
);
