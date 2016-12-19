import { on, observes, default as computed } from 'ember-addons/ember-computed-decorators';
import { findRawTemplate } from 'discourse/lib/raw-templates';

export default Ember.Component.extend({
  @computed('placeholderKey')
  placeholder(placeholderKey) {
    return placeholderKey ? I18n.t(placeholderKey) : '';
  },

  @observes('groupNames')
  _update() {
    if (this.get('canReceiveUpdates') === 'true')
      this._initializeAutocomplete({updateData: true});
  },

  @on('didInsertElement')
  _initializeAutocomplete(opts) {
    var self = this;
    var selectedGroups;
    var groupNames = this.get('groupNames');

    self.$('input').autocomplete({
      allowAny: false,
      items: _.isArray(groupNames) ? groupNames : (Ember.isEmpty(groupNames)) ? [] : [groupNames],
      single: this.get('single'),
      updateData: (opts && opts.updateData) ? opts.updateData : false,
      onChangeItems: function(items){
        selectedGroups = items;
        self.set("groupNames", items.join(","));
      },
      transformComplete: function(g) {
        return g.name;
      },
      dataSource: function(term) {
        return self.get("groupFinder")(term).then(function(groups){

          if(!selectedGroups){
            return groups;
          }

          return groups.filter(function(group){
            return !selectedGroups.any(function(s){return s === group.name;});
          });
        });
      },
      template: findRawTemplate('group-selector-autocomplete')
    });
  }
});
