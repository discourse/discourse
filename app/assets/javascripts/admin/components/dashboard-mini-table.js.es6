import { ajax } from 'discourse/lib/ajax';
import computed from 'ember-addons/ember-computed-decorators';

export default Ember.Component.extend({
  classNames: ["dashboard-mini-table"],

  total: null,
  labels: null,
  title: null,
  chartData: null,
  isLoading: false,
  help: null,
  helpPage: null,

  didInsertElement() {
    this._super();

    this.fetchReport.apply(this);
  },

  @computed("dataSourceName")
  dataSource(dataSourceName) {
    return `/admin/reports/${dataSourceName}`;
  },

  fetchReport() {
    this.set("isLoading", true);

    ajax(this.get("dataSource")).then((response) => {
      const report = response.report;

      this.setProperties({
        labels: report.data.map(r => r.x),
        dataset: report.data.map(r => r.y),
        total: report.total,
        title: report.title,
        chartData: report.data
      });
    }).finally(() => {
      this.set("isLoading", false);
    });
  }
});
