import { default as computed } from 'ember-addons/ember-computed-decorators';

export default Ember.Controller.extend({
  application: Ember.inject.controller(),
  destroying: null,

  @computed("model.automatic")
  tabs(automatic) {
    const defaultTabs = [
      { route: 'group.manage.interaction', title: 'groups.manage.interaction.title' },
      { route: 'group.manage.logs', title: 'groups.manage.logs.title' },
    ];

    if (!automatic) {
      defaultTabs.splice(0, 0,
        { route: 'group.manage.profile', title: 'groups.manage.profile.title' }
      );

      defaultTabs.splice(1, 0,
        { route: 'group.manage.membership', title: 'groups.manage.membership.title' }
      );
    }

    return defaultTabs;
  },

  actions: {
    destroy() {
      const group = this.get('model');
      this.set('destroying', true);

      bootbox.confirm(
        I18n.t("admin.groups.delete_confirm"),
        I18n.t("no_value"),
        I18n.t("yes_value"),
        confirmed => {
          if (confirmed) {
            group.destroy().then(() => {
              self.transitionToRoute('groups.index');
            }).catch(() => bootbox.alert(I18n.t("admin.groups.delete_failed")))
              .finally(() => this.set('destroying', false));
          } else {
            this.set('destroying', false);
          }
        }
      );
    }
  }
});
