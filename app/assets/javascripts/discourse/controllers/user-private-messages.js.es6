import computed from 'ember-addons/ember-computed-decorators';

export default Ember.Controller.extend({

  pmView: false,

  privateMessagesActive: Em.computed.equal('pmView', 'index'),
  privateMessagesMineActive: Em.computed.equal('pmView', 'mine'),
  privateMessagesUnreadActive: Em.computed.equal('pmView', 'unread'),
  isGroup: Em.computed.equal('pmView', 'groups'),


  @computed('model.groups', 'groupFilter', 'pmView')
  groupPMStats(groups, filter, pmView) {
    if (groups) {
      return groups.filter(group => group.has_messages)
                   .map(g => {
                        return {
                          name: g.name,
                          active: (g.name === filter && pmView === "groups")
                        };
                   });
    }
  }
});
