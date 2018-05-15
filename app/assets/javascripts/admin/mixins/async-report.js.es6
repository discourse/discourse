import computed from "ember-addons/ember-computed-decorators";

export default Ember.Mixin.create({
  classNameBindings: ["isLoading"],

  reports: null,
  reportKeys: null,
  isLoading: false,
  dataSourceNames: "",

  init() {
    this._super();

    this.set("reports", Ember.Object.create());
    this.set("reportKeys", []);

    this._channels = this.get("dataSources");
    this._callback = (report) => {
      if (this.get("reportKeys").includes(report.report_key)) {
        Em.run.next(() => {
          if (this.get("reportKeys").includes(report.report_key)) {
            const previousReport = this.get(`reports.${report.report_key}`);
            this.set(`reports.${report.report_key}`, this.loadReport(report, previousReport));
            this.renderReport();
          }
        });
      }
    };

    // in case we did not subscribe in time ensure we always grab the
    // last thing on the channel
    this.subscribe(-2);
  },

  subscribe(position) {
    this._channels.forEach(channel => {
      this.messageBus.subscribe(channel, this._callback, position);
    });
  },

  unsubscribe() {
    this._channels.forEach(channel => {
      this.messageBus.unsubscribe(channel, this._callback);
    });
  },

  @computed("dataSourceNames")
  dataSources(dataSourceNames) {
    return dataSourceNames.split(",").map(source => `/admin/reports/${source}`);
  },

  willDestroyElement() {
    this._super();

    this.unsubscribe();
  },

  didInsertElement() {
    this._super();

    Ember.run.later(this, function() {
      this.fetchReport()
          .finally(() => {
            this.renderReport();
          });
    }, 500);
  },

  didUpdateAttrs() {
    this._super();
    this.fetchReport()
        .finally(() => {
          this.renderReport();
        });
  },

  renderReport() {
    if (!this.element || this.isDestroying || this.isDestroyed) return;

    const reports = _.values(this.get("reports"));

    if (!reports.length) return;

    const title = reports.map(report => report.title).join(", ");

    if (reports.map(report => report.processing).includes(true)) {
      const loading = I18n.t("conditional_loading_section.loading");
      this.set("loadingTitle", `${loading}\n\n${title}`);
      return;
    }

    this.setProperties({ title, isLoading: false});
  },

  loadReport() {},

  fetchReport() {
    this.set("isLoading", true);
    this.set("loadingTitle", I18n.t("conditional_loading_section.loading"));
  },
});
