import { ajax } from "discourse/lib/ajax";
import { escapeExpression } from "discourse/lib/utilities";

export default createWidget("deals-page", {
  tagName: "div.deals-page",
  buildKey: () => "deals-page",

  defaultState() {
    return {
      deals: [],
      loading: false,
      filters: {
        category: "all",
        sort: "hot",
        minPrice: null,
        maxPrice: null,
        minDiscount: null
      },
      showFilters: false
    };
  },

  didRender() {
    if (this.state.deals.length === 0 && !this.state.loading) {
      this.loadDeals();
    }
  },

  html(attrs, state) {
    const { deals, loading, filters, showFilters } = state;

    return [
      h("div.deals-header", [
        h("h1.title", "🔥 Hot Deals"),
        h("div.header-actions", [
          h("button.submit-deal-btn", {
            click: () => this.openSubmitModal()
          }, "+ Submit Deal"),
          h("button.toggle-filters-btn", {
            click: () => this.toggleFilters()
          }, "🔍 Filters")
        ])
      ]),
      showFilters ? h("div.filters-panel", this.renderFilters(filters)) : null,
      h("div.sort-tabs", this.renderSortTabs(filters.sort)),
      h("div.deals-grid", this.renderDealsGrid(deals, loading))
    ];
  },

  renderFilters(filters) {
    return [
      h("div.filter-group", [
        h("label", "Category"),
        h("select.category-select", {
          change: (e) => this.setFilter("category", e.target.value)
        }, [
          h("option", { value: "all" }, "All Categories"),
          h("option", { value: "electronics" }, "Electronics"),
          h("option", { value: "fashion" }, "Fashion"),
          h("option", { value: "home" }, "Home & Garden"),
          h("option", { value: "travel" }, "Travel"),
          h("option", { value: "food" }, "Food & Dining"),
          h("option", { value: "entertainment" }, "Entertainment")
        ])
      ]),
      h("div.filter-group", [
        h("label", "Price Range"),
        h("div.price-inputs", [
          h("input.price-input", {
            type: "number",
            placeholder: "Min Price",
            change: (e) => this.setFilter("minPrice", e.target.value)
          }),
          h("span.price-separator", "-"),
          h("input.price-input", {
            type: "number",
            placeholder: "Max Price",
            change: (e) => this.setFilter("maxPrice", e.target.value)
          })
        ])
      ]),
      h("div.filter-group", [
        h("label", "Min Discount (%)"),
        h("input.discount-input", {
          type: "number",
          placeholder: "e.g., 20",
          change: (e) => this.setFilter("minDiscount", e.target.value)
        })
      ])
    ];
  },

  renderSortTabs(activeSort) {
    const sorts = [
      { id: "hot", label: "🔥 Hot" },
      { id: "new", label: "🕐 New" },
      { id: "expiring", label: "⏰ Expiring Soon" },
      { id: "price_asc", label: "💰 Price: Low to High" },
      { id: "price_desc", label: "💎 Price: High to Low" }
    ];

    return h("div.sort-tabs", sorts.map(sort =>
      h("button.sort-tab", {
        className: activeSort === sort.id ? "active" : "",
        click: () => this.setSort(sort.id)
      }, sort.label)
    ));
  },

  renderDealsGrid(deals, loading) {
    if (loading && deals.length === 0) {
      return h("div.loading-spinner", "Loading deals...");
    }

    if (!deals || deals.length === 0) {
      return h("div.empty-state", [
        h("div.empty-icon", "💸"),
        h("p", "No deals found"),
        h("p.hint", "Submit a deal to get started!")
      ]);
    }

    return h("div.grid-container", deals.map(deal =>
      this.attach("deal-card", { deal })
    ));
  },

  toggleFilters() {
    this.state.showFilters = !this.state.showFilters;
    this.scheduleRerender();
  },

  setFilter(key, value) {
    this.state.filters[key] = value;
    this.loadDeals();
  },

  setSort(sort) {
    this.state.filters.sort = sort;
    this.loadDeals();
  },

  loadDeals() {
    this.state.loading = true;
    this.scheduleRerender();

    const params = {
      sort: this.state.filters.sort
    };

    if (this.state.filters.category !== "all") {
      params.category = this.state.filters.category;
    }
    if (this.state.filters.minPrice) {
      params.min_price = this.state.filters.minPrice;
    }
    if (this.state.filters.maxPrice) {
      params.max_price = this.state.filters.maxPrice;
    }
    if (this.state.filters.minDiscount) {
      params.min_discount = this.state.filters.minDiscount;
    }

    ajax("/tangyzen/deals.json", { data: params })
      .then(result => {
        this.state.deals = result.deals || [];
        this.state.loading = false;
        this.scheduleRerender();
      })
      .catch(() => {
        this.state.loading = false;
        this.scheduleRerender();
      });
  },

  openSubmitModal() {
    // Trigger the submit-deal widget
    this.appEvents.trigger("tangyzen:open-submit-modal");
  }
});
