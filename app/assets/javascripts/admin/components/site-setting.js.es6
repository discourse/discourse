import BufferedContent from 'discourse/mixins/buffered-content';
import SiteSetting from 'admin/models/site-setting';
import { propertyNotEqual } from 'discourse/lib/computed';
import computed from 'ember-addons/ember-computed-decorators';
import { categoryLinkHTML } from 'discourse/helpers/category-link';

const CustomTypes = ['bool', 'enum', 'list', 'url_list', 'host_list', 'category_list', 'value_list'];

export default Ember.Component.extend(BufferedContent, {
  classNameBindings: [':row', ':setting', 'setting.overridden', 'typeClass'],
  content: Ember.computed.alias('setting'),
  dirty: propertyNotEqual('buffered.value', 'setting.value'),
  validationMessage: null,

  @computed("setting", "buffered.value")
  preview(setting, value) {
    // A bit hacky, but allows us to use helpers
    if (setting.get('setting') === 'category_style') {
      let category = this.site.get('categories.firstObject');
      if (category) {
        return categoryLinkHTML(category, {
          categoryStyle: value
        });
      }
    }

    let preview = setting.get('preview');
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
    const setting = this.get('buffered'),
      action = SiteSetting.update(setting.get('setting'), setting.get('value'));
    action.then(() => {
      this.set('validationMessage', null);
      this.commitBuffer();
    }).catch((e) => {
      if (e.jqXHR.responseJSON && e.jqXHR.responseJSON.errors) {
        this.set('validationMessage', e.jqXHR.responseJSON.errors[0]);
      } else {
        this.set('validationMessage', I18n.t('generic_error'));
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
