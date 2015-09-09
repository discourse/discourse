import BufferedContent from 'discourse/mixins/buffered-content';
import ScrollTop from 'discourse/mixins/scroll-top';
import SiteSetting from 'admin/models/site-setting';
import { propertyNotEqual } from 'discourse/lib/computed';
import computed from 'ember-addons/ember-computed-decorators';

const CustomTypes = ['bool', 'enum', 'list', 'url_list', 'host_list', 'category_list', 'value_list'];

export default Ember.Component.extend(BufferedContent, ScrollTop, {
  classNameBindings: [':row', ':setting', 'setting.overridden', 'typeClass'],
  content: Ember.computed.alias('setting'),
  dirty: propertyNotEqual('buffered.value', 'setting.value'),
  validationMessage: null,

  @computed("setting.preview", "buffered.value")
  preview(preview, value) {
    if (preview) {
      return new Handlebars.SafeString("<div class='preview'>" + preview.replace(/\{\{value\}\}/g, value) + "</div>");
    }
  },

  @computed('componentType')
  typeClass(componentType) {
    return componentType.replace(/\_/g, '-');
  },

  @computed("setting.setting")
  settingName(setting) {
    return setting.replace(/\_/g, ' ');
  },

  @computed("setting.type")
  componentType(type) {
    return CustomTypes.indexOf(type) !== -1 ? type : 'string';
  },

  @computed("typeClass")
  componentName(typeClass) {
    return "site-settings/" + typeClass;
  },

  _watchEnterKey: function() {
    const self = this;
    this.$().on("keydown.site-setting-enter", ".input-setting-string", function (e) {
      if (e.keyCode === 13) { // enter key
        self._save();
      }
    });
  }.on('didInsertElement'),

  _removeBindings: function() {
    this.$().off("keydown.site-setting-enter");
  }.on("willDestroyElement"),

  _save() {
    const self = this,
          setting = this.get('buffered');
    SiteSetting.update(setting.get('setting'), setting.get('value')).then(function() {
      self.set('validationMessage', null);
      self.commitBuffer();
    }).catch(function(e) {
      if (e.jqXHR.responseJSON && e.jqXHR.responseJSON.errors) {
        self.set('validationMessage', e.jqXHR.responseJSON.errors[0]);
      } else {
        self.set('validationMessage', I18n.t('generic_error'));
      }
    });
  },

  actions: {
    save() {
      this._save();
    },

    resetDefault() {
      this.set('buffered.value', this.get('setting.default'));
      this._save();
    },

    cancel() {
      this.rollbackBuffer();
    }
  }

});
