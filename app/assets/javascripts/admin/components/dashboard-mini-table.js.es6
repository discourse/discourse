import { ajax } from 'discourse/lib/ajax';
import computed from 'ember-addons/ember-computed-decorators';

export default Ember.Component.extend({
  classNames: ["dashboard-mini-table"],

  classNameBindings: ["isLoading"],

  total: null,
  labels: null,
  title: null,
  chartData: null,
  isLoading: false,
  help: null,
  helpPage: null,
  model: null,

  didInsertElement() {
    this._super();

    if (this.get("dataSourceName")){
      this._fetchReport();
    } else if (this.get("model")) {
      this._setPropertiesFromModel(this.get("model"));
    }
  },

  didUpdateAttrs() {
    this._super();

    if (this.get("model")) {
      this._setPropertiesFromModel(this.get("model"));
    }
  },

  @computed("dataSourceName")
  dataSource(dataSourceName) {
    return `/admin/reports/${dataSourceName}`;
  },

  _fetchReport() {
    if (this.get("isLoading")) return;

    this.set("isLoading", true);

    ajax(this.get("dataSource"))
      .then((response) => {
        this._setPropertiesFromModel(response.report);
      }).finally(() => {
        this.set("isLoading", false);
      });
  },

  _setPropertiesFromModel(model) {
    const data = model.data.sort((a, b) => a.x >= b.x);

    this.setProperties({
      labels: data.map(r => r.x),
      dataset: data.map(r => r.y),
      total: model.total,
      title: model.title,
      chartData: data
    });
  }
});
