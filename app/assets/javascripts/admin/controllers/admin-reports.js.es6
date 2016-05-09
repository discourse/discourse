import { exportEntity } from 'discourse/lib/export-csv';
import { outputExportResult } from 'discourse/lib/export-result';
import Report from 'admin/models/report';
import computed from 'ember-addons/ember-computed-decorators';

export default Ember.Controller.extend({
  queryParams: ["mode", "start-date", "end-date", "category-id", "group-id"],
  viewMode: 'graph',
  viewingTable: Em.computed.equal('viewMode', 'table'),
  viewingGraph: Em.computed.equal('viewMode', 'graph'),
  startDate: null,
  endDate: null,
  categoryId: null,
  groupId: null,
  refreshing: false,

  @computed()
  categoryOptions() {
    const arr = [{name: I18n.t('category.all'), value: 'all'}];
    return arr.concat(Discourse.Site.currentProp('sortedCategories').map((i) => {return {name: i.get('name'), value: i.get('id')};}));
  },

  @computed()
  groupOptions() {
    const arr = [{name: I18n.t('admin.dashboard.reports.groups'), value: 'all'}];
    return arr.concat(this.site.groups.map((i) => {return {name: i['name'], value: i['id']};}));
  },

  @computed('model.type')
  showCategoryOptions(modelType) {
    return !modelType.match(/_private_messages$/) && !modelType.match(/^page_view_/);
  },

  @computed('model.type')
  showGroupOptions(modelType) {
    return modelType === "visits" || modelType === "signups" || modelType === "profile_views";
  },

  actions: {
    refreshReport() {
      var q;
      this.set("refreshing", true);

      this.setProperties({
        'start-date': this.get('startDate'),
        'end-date': this.get('endDate'),
        'category-id': this.get('categoryId'),
      });

      if (this.get('groupId')){
        this.set('group-id', this.get('groupId'));
      }

      q = Report.find(this.get("model.type"), this.get("startDate"), this.get("endDate"), this.get("categoryId"), this.get("groupId"));
      q.then(m => this.set("model", m)).finally(() => this.set("refreshing", false));
    },

    viewAsTable() {
      this.set('viewMode', 'table');
    },

    viewAsGraph() {
      this.set('viewMode', 'graph');
    },

    exportCsv() {
      exportEntity('report', {
        name: this.get("model.type"),
        start_date: this.get('startDate'),
        end_date: this.get('endDate'),
        category_id: this.get('categoryId') === 'all' ? undefined : this.get('categoryId'),
        group_id: this.get('groupId') === 'all' ? undefined : this.get('groupId')
      }).then(outputExportResult);
    }
  }
});
