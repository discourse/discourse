import computed from 'ember-addons/ember-computed-decorators';

export default Ember.Mixin.create({
  classNameBindings: ["isLoading"],

  report: null,

  init() {
    this._super();

    this._channel = this.get("dataSource");
    this._callback = (report) => {
      if (report.report_key = this.get("reportKey")) {
        Em.run.next(() => {
          if (report.report_key = this.get("reportKey")) {
            this.loadReport(report);
            this.set("isLoading", false);
            this.renderReport();
          }
        });
      }
    };
    // in case we did not subscribe in time ensure we always grab the
    // last thing on the channel
    this.messageBus.subscribe(this._channel, this._callback, -2);
  },

  willDestroyElement() {
    this._super();
    this.messageBus.unsubscribe(this._channel, this._callback);
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

  loadReport() {},

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
