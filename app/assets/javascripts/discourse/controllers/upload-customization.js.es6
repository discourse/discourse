import ModalFunctionality from 'discourse/mixins/modal-functionality';

export default Ember.Controller.extend(ModalFunctionality, {
  notReady: Em.computed.not('ready'),
  needs: ['adminCustomizeCssHtml'],

  ready: function() {
    try {
      const parsed = JSON.parse(this.get('customizationFile'));
      return !!parsed["site_customization"];
    } catch (e) {
      return false;
    }
  }.property('customizationFile'),

  actions: {
    createCustomization: function() {
      const object = JSON.parse(this.get('customizationFile')).site_customization;

      // Slight fixup before creating object
      object.enabled = false;
      delete object.id;
      delete object.key;

      const controller = this.get('controllers.adminCustomizeCssHtml');
      controller.send('newCustomization', object);
    }
  }

});
