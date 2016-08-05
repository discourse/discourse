export default Ember.ArrayController.extend({
  actions: {
    selectTagGroup: function(tagGroup) {
      if (this.get('selectedItem')) { this.get('selectedItem').set('selected', false); }
      this.set('selectedItem', tagGroup);
      tagGroup.set('selected', true);
      tagGroup.set('savingStatus', null);
      this.transitionToRoute('tagGroups.show', tagGroup);
    },

    newTagGroup: function() {
      const newTagGroup = this.store.createRecord('tag-group');
      newTagGroup.set('name', I18n.t('tagging.groups.new_name'));
      this.pushObject(newTagGroup);
      this.send('selectTagGroup', newTagGroup);
    }
  }
});
