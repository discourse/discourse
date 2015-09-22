import { url } from 'discourse/lib/computed';

const sections = ['css', 'header', 'top', 'footer', 'head-tag', 'body-tag',
                  'mobile-css', 'mobile-header', 'mobile-top', 'mobile-footer',
                  'embedded-css'];

const activeSections = {};
sections.forEach(function(s) {
  activeSections[Ember.String.camelize(s) + "Active"] = Ember.computed.equal('section', s);
});


export default Ember.Controller.extend(activeSections, {
  maximized: false,
  section: null,

  previewUrl: url("model.key", "/?preview-style=%@"),
  downloadUrl: url('model.id', '/admin/site_customizations/%@'),

  mobile: function() {
    return this.get('section').indexOf('mobile-') === 0;
  }.property('section'),

  maximizeIcon: function() {
    return this.get('maximized') ? 'compress' : 'expand';
  }.property('maximized'),

  saveButtonText: function() {
    return this.get('model.isSaving') ? I18n.t('saving') : I18n.t('admin.customize.save');
  }.property('model.isSaving'),

  saveDisabled: function() {
    return !this.get('model.changed') || this.get('model.isSaving');
  }.property('model.changed', 'model.isSaving'),

  needs: ['adminCustomizeCssHtml'],

  undoPreviewUrl: url('/?preview-style='),
  defaultStyleUrl: url('/?preview-style=default'),

  actions: {
    save() {
      this.get('model').saveChanges();
    },

    destroy() {
      const self = this;
      return bootbox.confirm(I18n.t("admin.customize.delete_confirm"), I18n.t("no_value"), I18n.t("yes_value"), function(result) {
        if (result) {
          const model = self.get('model');
          model.destroyRecord().then(function() {
            self.get('controllers.adminCustomizeCssHtml').get('model').removeObject(model);
            self.transitionToRoute('adminCustomizeCssHtml');
          });
        }
      });
    },

    toggleMaximize: function() {
      this.toggleProperty('maximized');
    },

    toggleMobile: function() {
      const section = this.get('section');

      // Try to send to the same tab as before
      let dest;
      if (this.get('mobile')) {
        dest = section.replace('mobile-', '');
        if (sections.indexOf(dest) === -1) { dest = 'css'; }
      } else {
        dest = 'mobile-' + section;
        if (sections.indexOf(dest) === -1) { dest = 'mobile-css'; }
      }
      this.replaceRoute('adminCustomizeCssHtml.show', this.get('model.id'), dest);
    }
  }

});
