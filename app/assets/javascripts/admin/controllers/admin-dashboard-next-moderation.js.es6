import computed from "ember-addons/ember-computed-decorators";
import PeriodComputationMixin from "admin/mixins/period-computation";

export default Ember.Controller.extend(PeriodComputationMixin, {
  exceptionController: Ember.inject.controller("exception"),

  @computed
  flagsStatusOptions() {
    return {
      table: {
        total: false,
        perPage: 10
      }
    };
  },

  _reportsForPeriodURL(period) {
    return Discourse.getURL(`/admin/dashboard/moderation?period=${period}`);
  }
});
