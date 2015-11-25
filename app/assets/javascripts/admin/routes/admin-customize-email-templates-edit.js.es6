import { scrollTop } from 'discourse/mixins/scroll-top';

export default Ember.Route.extend({
  model(params) {
    const all = this.modelFor('adminCustomizeEmailTemplates');
    return all.findProperty('id', params.id);
  },

  setupController(controller, model) {
    controller.set('emailTemplate', model);
    scrollTop();
  }
});
