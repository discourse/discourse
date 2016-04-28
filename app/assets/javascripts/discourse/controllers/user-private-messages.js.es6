import computed from 'ember-addons/ember-computed-decorators';
import Topic from 'discourse/models/topic';

export default Ember.Controller.extend({
  needs: ["application", "user-topics-list", "user"],
  pmView: false,
  viewingSelf: Em.computed.alias('controllers.user.viewingSelf'),
  isGroup: Em.computed.equal('pmView', 'groups'),
  currentPath: Em.computed.alias('controllers.application.currentPath'),
  selected: Em.computed.alias('controllers.user-topics-list.selected'),
  bulkSelectEnabled: Em.computed.alias('controllers.user-topics-list.bulkSelectEnabled'),

  showNewPM: function(){
    return this.get('controllers.user.viewingSelf') &&
           Discourse.User.currentProp('can_send_private_messages');
  }.property('controllers.user.viewingSelf'),

  @computed('selected.[]', 'bulkSelectEnabled')
  hasSelection(selected, bulkSelectEnabled){
    return bulkSelectEnabled && selected && selected.length > 0;
  },

  @computed('hasSelection', 'pmView', 'archive')
  canMoveToInbox(hasSelection, pmView, archive){
    return hasSelection && (pmView === "archive" || archive);
  },

  @computed('hasSelection', 'pmView', 'archive')
  canArchive(hasSelection, pmView, archive){
    return hasSelection && pmView !== "archive" && !archive;
  },


  bulkOperation(operation) {
    const selected = this.get('selected');
    var params = {type: operation};
    if (this.get('isGroup')) {
      params.group = this.get('groupFilter');
    }

    Topic.bulkOperation(selected,params).then(() => {
      const model = this.get('controllers.user-topics-list.model');
      const topics = model.get('topics');
      topics.removeObjects(selected);
      selected.clear();
      model.loadMore();
    }, () => {
      bootbox.alert(I18n.t("user.messages.failed_to_move"));
    });
  },

  actions: {
    archive() {
      this.bulkOperation("archive_messages");
    },
    toInbox() {
      this.bulkOperation("move_messages_to_inbox");
    },
    toggleBulkSelect(){
      this.toggleProperty("bulkSelectEnabled");
    },
    selectAll() {
      $('input.bulk-select:not(checked)').click();
    }
  }
});
