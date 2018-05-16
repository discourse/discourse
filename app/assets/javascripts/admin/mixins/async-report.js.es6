import computed from "ember-addons/ember-computed-decorators";

export default Ember.Mixin.create({
  classNameBindings: ["isLoading"],

  reports: null,
  isLoading: false,
  dataSourceNames: "",

  init() {
    this._super();
    this.set("reports", Ember.Object.create());
  },

  @computed("dataSourceNames")
  dataSources(dataSourceNames) {
    return dataSourceNames.split(",").map(source => `/admin/reports/${source}`);
  },

  didInsertElement() {
    this._super();
    this.fetchReport()
        .finally(() => {
          this.renderReport();
        });
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
