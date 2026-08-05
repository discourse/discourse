import { tracked } from "@glimmer/tracking";
import { click, find, render, triggerKeyEvent } from "@ember/test-helpers";
import { module, test } from "qunit";
import SiteTrafficBreakdownCard from "discourse/admin/components/dashboard/site-traffic-breakdown-card";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

class CardState {
  @tracked activeTab = "traffic_sources";

  tabs = [
    { key: "traffic_sources", label: "Referrers" },
    { key: "countries", label: "Countries" },
    { key: "networks", label: "Networks" },
  ];

  rows = Array.from({ length: 9 }, (_value, index) => ({
    value: `source-${index}.example`,
    displayLabel: `source-${index}.example`,
    formattedPageviews: `${9 - index}`,
    filterable: true,
  }));
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

    test("keeps Entry URL navigation separate from filtering", async function (assert) {
      this.state = new CardState();
      this.state.activeTab = "entry_urls";
      this.state.tabs = [
        { key: "top_urls", label: "Top URLs" },
        { key: "entry_urls", label: "Entry URLs" },
      ];
      this.state.rows = [
        {
          value: "/privacy",
          displayLabel: "/privacy",
          formattedPageviews: "3",
          filterable: true,
        },
        {
          value: "/about",
          displayLabel: "/about",
          formattedPageviews: "2",
          filterable: false,
        },
      ];
      this.appliedFilter = null;
      this.selectTab = (tabKey) => {
        this.state.activeTab = tabKey;
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
            @filterDimension="entry_url"
            @onSelectTab={{this.selectTab}}
            @onApplyFilter={{this.applyFilter}}
            @onViewMore={{this.showMore}}
          />
        </template>
      );

      assert
        .dom("[data-test-entry-url-link]")
        .hasAttribute("href", "/privacy", "the Entry URL remains a real link");
      assert
        .dom("[data-test-entry-url-filter]")
        .hasAttribute(
          "aria-label",
          "Filter by /privacy",
          "the Entry URL has a separate accessible filter action"
        );
      assert
        .dom("[data-test-entry-url-link] [data-test-entry-url-filter]")
        .doesNotExist("the Entry URL actions are not nested");
      assert
        .dom("a.site-traffic-detail__row[data-test-breakdown-row]")
        .hasAttribute(
          "href",
          "/about",
          "a safe nonfilterable Entry URL remains a link"
        );

      await click("[data-test-entry-url-filter]");
      assert.deepEqual(
        this.appliedFilter,
        { dimension: "entry_url", value: "/privacy" },
        "the separate action applies the exact Entry URL filter"
      );
    });
  }
);
