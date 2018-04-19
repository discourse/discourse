import { ajax } from 'discourse/lib/ajax';
import computed from 'ember-addons/ember-computed-decorators';

export default Ember.Component.extend({
  classNames: ["dashboard-table"],

  classNameBindings: ["isLoading"],

  total: null,
  labels: null,
  title: null,
  chartData: null,
  isLoading: false,
  help: null,
  helpPage: null,
  model: null,

  transformModel(model) {
    const data = model.data.sort((a, b) => a.x >= b.x);

    return {
      labels: model.labels,
      values: data
    };
  },

  didInsertElement() {
    this._super();
    this._initializeTable();
  },

  didUpdateAttrs() {
    this._super();
    this._initializeTable();
  },

  @computed("dataSourceName")
  dataSource(dataSourceName) {
    return `/admin/reports/${dataSourceName}`;
  },

  _initializeTable() {
    if (this.get("model") && !this.get("values")) {
      this._setPropertiesFromModel(this.get("model"));
    } else if (this.get("dataSource")) {
      this._fetchReport();
    }
  },

  _fetchReport() {
    if (this.get("isLoading")) return;

    this.set("isLoading", true);

    let payload = {data: {}};

    if (this.get("startDate")) {
      payload.data.start_date = this.get("startDate").toISOString();
    }

    if (this.get("endDate")) {
      payload.data.end_date = this.get("endDate").toISOString();
    }

    ajax(this.get("dataSource"), payload)
      .then((response) => {
        this._setPropertiesFromModel(response.report);
      }).finally(() => {
        this.set("isLoading", false);
      });
  },

  _setPropertiesFromModel(model) {
    const { labels, values } = this.transformModel(model);

    this.setProperties({
      labels,
      values,
      total: model.total,
      title: model.title
    });
  }
});
