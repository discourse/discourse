export default Ember.Controller.extend({
  needs: ['tagGroups'],

  actions: {
    save() {
      this.get('model').save();
    },

    destroy() {
      const self = this;
      return bootbox.confirm(
        I18n.t("tagging.groups.confirm_delete"),
        I18n.t("no_value"),
        I18n.t("yes_value"),
        function(destroy) {
          if (destroy) {
            const c = self.controllerFor('tagGroups');
            return self.get('model').destroy().then(function() {
              c.removeObject(self.get('model'));
              self.transitionToRoute('tagGroups');
            });
          }
        }
      );
    }
  }
});
