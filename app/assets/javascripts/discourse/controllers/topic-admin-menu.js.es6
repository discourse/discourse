import ObjectController from 'discourse/controllers/object';

// This controller supports the admin menu on topics
export default ObjectController.extend({
  menuVisible: false,
  showRecover: Em.computed.and('model.deleted', 'model.details.can_recover'),
  isFeatured: Em.computed.or("model.pinned_at", "model.isBanner"),

  actions: {
    show: function() { this.set('menuVisible', true); },
    hide: function() { this.set('menuVisible', false); }
  }

});
