import BadgeSelectController from "discourse/mixins/badge-select-controller";

export default Ember.Controller.extend(BadgeSelectController, {

  filteredList: function() {
    return this.get('model').filterBy('badge.allow_title', true);
  }.property('model')

});
