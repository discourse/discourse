import BufferedContent from 'discourse/mixins/buffered-content';
import ScrollTop from 'discourse/mixins/scroll-top';
import SiteSetting from 'admin/models/site-setting';
import { propertyNotEqual } from 'discourse/lib/computed';
import computed from 'ember-addons/ember-computed-decorators';

const CustomTypes = ['bool', 'enum', 'list', 'url_list', 'host_list'];

export default Ember.Component.extend(BufferedContent, ScrollTop, {
  classNameBindings: [':row', ':setting', 'setting.overridden', 'typeClass'],
  content: Ember.computed.alias('setting'),
  dirty: propertyNotEqual('buffered.value', 'setting.value'),
  validationMessage: null,

  preview: function() {
    const preview = this.get('setting.preview');
    if (preview) {
      return new Handlebars.SafeString("<div class='preview'>" +
                                        preview.replace(/\{\{value\}\}/g, this.get('buffered.value')) +
                                        "</div>");
    }
  }.property('buffered.value'),

  @computed('partialType')
  typeClass() {
    return this.get('partialType').replace("_", "-");
  },

  @computed('buffered.value')
  enabled: {
    get() {
      const bufferedValue = this.get('buffered.value');
      if (Ember.isEmpty(bufferedValue)) { return false; }
      return bufferedValue === 'true';
    },
    set(key, value) {
      this.set('buffered.value', value ? 'true' : 'false');
    }
  },

  settingName: function() {
    return this.get('setting.setting').replace(/\_/g, ' ');
  }.property('setting.setting'),

  partialType: function()  {
    let type = this.get('setting.type');
    return CustomTypes.indexOf(type) !== -1 ? type : 'string';
  }.property('setting.type'),

  partialName: function() {
    return 'admin/templates/site-settings/' + this.get('partialType');
  }.property('partialType'),

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
    const setting = this.get('buffered');
    const self = this;
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
