import computed from 'ember-addons/ember-computed-decorators';
import Report from "admin/models/report";

export default Ember.Mixin.create({
  classNameBindings: ["isLoading"],

  report: null,

  init() {
    this._super();

    this.messageBus.subscribe(this.get("dataSource"), report => {
      const formatDate = (date) => moment(date).format("YYYYMMDD");

      // this check is done to avoid loading a chart after period has changed
      if (
          (this.get("startDate") && formatDate(report.start_date) === formatDate(this.get("startDate"))) &&
          (this.get("endDate") && formatDate(report.end_date) === formatDate(this.get("endDate")))
         ) {
        this._setPropertiesFromReport(Report.create(report));
        this.set("isLoading", false);
        this.renderReport();
      } else {
        this._setPropertiesFromReport(Report.create(report));
        this.set("isLoading", false);
        this.renderReport();
      }
    });
  },

  didInsertElement() {
    this._super();

    Ember.run.later(this, function() {
      this.fetchReport();
    }, 500);
  },

  didUpdateAttrs() {
    this._super();

    this.fetchReport();
  },

  renderReport() {},

  @computed("dataSourceName")
  dataSource(dataSourceName) {
    return `/admin/reports/${dataSourceName}`;
  },

  @computed("report")
  labels(report) {
    if (!report) return;
    return Ember.makeArray(report.data).map(r => r.x);
  },

  @computed("report")
  values(report) {
    if (!report) return;
    return Ember.makeArray(report.data).map(r => r.y);
  },

  _setPropertiesFromReport(report) {
    if (!this.element || this.isDestroying || this.isDestroyed) { return; }
    this.setProperties({ report });
  }
});
