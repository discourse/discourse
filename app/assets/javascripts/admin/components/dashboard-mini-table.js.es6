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

  didInsertElement() {
    this._super();

    this.fetchReport();
  },

  @computed("dataSourceName")
  dataSource(dataSourceName) {
    return `/admin/reports/${dataSourceName}`;
  },

  fetchReport() {
    if (this.get("isLoading")) return;

    this.set("isLoading", true);

    ajax(this.get("dataSource"))
      .then((response) => {
        const report = response.report;
        const data = report.data.sort((a, b) => a.x >= b.x);

        this.setProperties({
          labels: data.map(r => r.x),
          dataset: data.map(r => r.y),
          total: report.total,
          title: report.title,
          chartData: data
        });
      }).finally(() => {
        this.set("isLoading", false);
      });
  }
});
