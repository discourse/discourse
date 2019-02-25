import computed from "ember-addons/ember-computed-decorators";

const PAGES_LIMIT = 8;

export default Ember.Component.extend({
  classNameBindings: ["sortable", "twoColumns"],
  classNames: ["admin-report-table"],
  sortable: false,
  sortDirection: 1,
  perPage: Ember.computed.alias("options.perPage"),
  page: 0,

  @computed("model.computedLabels.length")
  twoColumns(labelsLength) {
    return labelsLength === 2;
  },

  @computed("totalsForSample", "options.total", "model.dates_filtering")
  showTotalForSample(totalsForSample, total, datesFiltering) {
    // check if we have at least one cell which contains a value
    const sum = totalsForSample
      .map(t => t.value)
      .compact()
      .reduce((s, v) => s + v, 0);

    return sum >= 1 && total && datesFiltering;
  },

  @computed("model.total", "options.total", "twoColumns")
  showTotal(reportTotal, total, twoColumns) {
    return reportTotal && total && twoColumns;
  },

  @computed("model.data.length")
  showSortingUI(dataLength) {
    return dataLength >= 5;
  },

  @computed("totalsForSampleRow", "model.computedLabels")
  totalsForSample(row, labels) {
    return labels.map(label => {
      const computedLabel = label.compute(row);
      computedLabel.type = label.type;
      computedLabel.property = label.mainProperty;
      return computedLabel;
    });
  },

  @computed("model.data", "model.computedLabels")
  totalsForSampleRow(rows, labels) {
    if (!rows || !rows.length) return {};

    let totalsRow = {};

    labels.forEach(label => {
      const reducer = (sum, row) => {
        const computedLabel = label.compute(row);
        const value = computedLabel.value;

        if (!["seconds", "number", "percent"].includes(label.type)) {
          return;
        } else {
          return sum + Math.round(value || 0);
        }
      };

      const total = rows.reduce(reducer, 0);
      totalsRow[label.mainProperty] =
        label.type === "percent" ? Math.round(total / rows.length) : total;
    });

    return totalsRow;
  },

  @computed("sortLabel", "sortDirection", "model.data.[]")
  sortedData(sortLabel, sortDirection, data) {
    data = Ember.makeArray(data);

    if (sortLabel) {
      const compare = (label, direction) => {
        return (a, b) => {
          let aValue = label.compute(a).value;
          let bValue = label.compute(b).value;
          const result = aValue < bValue ? -1 : aValue > bValue ? 1 : 0;
          return result * direction;
        };
      };

      return data.sort(compare(sortLabel, sortDirection));
    }

    return data;
  },

  @computed("sortedData.[]", "perPage", "page")
  paginatedData(data, perPage, page) {
    if (perPage < data.length) {
      const start = perPage * page;
      return data.slice(start, start + perPage);
    }

    return data;
  },

  @computed("model.data", "perPage", "page")
  pages(data, perPage, page) {
    if (!data || data.length <= perPage) return [];

    const pagesIndexes = [];
    for (let i = 0; i < Math.ceil(data.length / perPage); i++) {
      pagesIndexes.push(i);
    }

    let pages = pagesIndexes.map(v => {
      return {
        page: v + 1,
        index: v,
        class: v === page ? "is-current" : null
      };
    });

    if (pages.length > PAGES_LIMIT) {
      const before = Math.max(0, page - PAGES_LIMIT / 2);
      const after = Math.max(PAGES_LIMIT, page + PAGES_LIMIT / 2);
      pages = pages.slice(before, after);
    }

    return pages;
  },

  actions: {
    changePage(page) {
      this.set("page", page);
    },

    sortByLabel(label) {
      if (this.get("sortLabel") === label) {
        this.set("sortDirection", this.get("sortDirection") === 1 ? -1 : 1);
      } else {
        this.set("sortLabel", label);
      }
    }
  }
});
