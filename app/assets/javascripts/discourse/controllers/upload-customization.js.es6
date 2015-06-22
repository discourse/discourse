import ModalFunctionality from 'discourse/mixins/modal-functionality';

export default Ember.Controller.extend(ModalFunctionality, {
  notReady: Em.computed.not('ready'),

  needs: ['admin-customize-css-html'],

  title: "hi",

  ready: function() {
    let parsed;
    try {
      parsed = JSON.parse(this.get('customizationFile'));
    } catch (e) {
      return false;
    }

    return !!parsed["site_customization"];
  }.property('customizationFile'),

  actions: {
    createCustomization: function() {
      const self = this;
      const object = JSON.parse(this.get('customizationFile')).site_customization;

      // Slight fixup before creating object
      object.enabled = false;
      delete object.id;
      delete object.key;

      const customization = Discourse.SiteCustomization.create(object);

      this.set('loading', true);
      customization.save().then(function(customization) {
        self.send('closeModal');
        self.set('loading', false);

        const parentController = self.get('controllers.admin-customize-css-html');
        parentController.pushObject(customization);
        parentController.set('selectedItem', customization);
      }).catch(function(xhr) {
        self.set('loading', false);
        if (xhr.responseJSON) {
          bootbox.alert(xhr.responseJSON.errors.join("<br>"));
        } else {
          bootbox.alert(I18n.t('generic_error'));
        }
      });
    }
  }

});
