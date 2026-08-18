import { run } from "@ember/runloop";
import { render, settled } from "@ember/test-helpers";
import { module, test } from "qunit";
import SiteTrafficExplorerFilterPills from "discourse/admin/components/site-traffic-explorer-filter-pills";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

module(
  "Integration | Component | SiteTrafficExplorerFilterPills",
  function (hooks) {
    setupRenderingTest(hooks);

    let resize;
    let valuesOverflow;
    let originalResizeObserver;

    hooks.beforeEach(function () {
      valuesOverflow = false;
      originalResizeObserver = globalThis.ResizeObserver;
      globalThis.ResizeObserver = class {
        constructor(callback) {
          this.callback = callback;
        }

        observe(element) {
          if (
            element.classList.contains("site-traffic-explorer__filter-controls")
          ) {
            resize = (width) => this.callback([{ contentRect: { width } }]);
          }
        }

        disconnect() {}
      };
      Object.defineProperty(HTMLElement.prototype, "scrollWidth", {
        configurable: true,
        get() {
          return this.classList.contains(
            "site-traffic-explorer__filter-pill-values"
          ) && valuesOverflow
            ? 200
            : 100;
        },
      });
      Object.defineProperty(HTMLElement.prototype, "clientWidth", {
        configurable: true,
        get() {
          return 100;
        },
      });

      this.filters = [
        {
          key: "top_url",
          pending: true,
          values: [
            { value: "/first", label: "/a-very-long-first-url" },
            { value: "/second", label: "/a-very-long-second-url" },
            { value: "/third", label: "/a-very-long-third-url" },
          ],
        },
      ];
      this.noop = () => {};
    });

    hooks.afterEach(function () {
      globalThis.ResizeObserver = originalResizeObserver;
      delete HTMLElement.prototype.scrollWidth;
      delete HTMLElement.prototype.clientWidth;
    });

    test("fits values again when the available width changes", async function (assert) {
      await render(
        <template>
          <SiteTrafficExplorerFilterPills
            @filters={{this.filters}}
            @hasPendingFilters={{true}}
            @pendingFilterCount={{3}}
            @removeFilterValue={{this.noop}}
            @clearFilter={{this.noop}}
            @clearAllFilters={{this.noop}}
            @applyFilters={{this.noop}}
          />
        </template>
      );

      valuesOverflow = true;
      run(() => resize(300));
      await settled();

      assert
        .dom("[data-test-site-traffic-filter-pill='top_url']")
        .includesText("+2", "the narrow pill hides overflowing values");

      valuesOverflow = false;
      run(() => resize(800));
      await settled();

      assert
        .dom("[data-test-site-traffic-filter-pill='top_url']")
        .includesText(
          "/a-very-long-third-url",
          "the widened pill restores values that now fit"
        );
      assert
        .dom(
          "[data-test-site-traffic-filter-pill='top_url'] .fk-d-menu__trigger"
        )
        .doesNotExist("the dropdown is removed when every value fits");

      valuesOverflow = true;
      run(() => resize(300));
      await settled();

      assert
        .dom("[data-test-site-traffic-filter-pill='top_url']")
        .includesText("+2", "the pill contracts after the container narrows");
    });
  }
);
