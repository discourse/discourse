import { url } from 'discourse/lib/computed';
import { default as computed } from 'ember-addons/ember-computed-decorators';

export default Ember.Controller.extend({
  maximized: false,
  section: null,

  targets: [
    {id: 0, name: I18n.t('admin.customize.theme.common')},
    {id: 1, name: I18n.t('admin.customize.theme.desktop')},
    {id: 2, name: I18n.t('admin.customize.theme.mobile')}
  ],

  currentTarget: 0,

  setTargetName: function(name) {
    let target;
    switch(name) {
      case "common": target = 0; break;
      case "desktop": target = 1; break;
      case "mobile": target = 2; break;
    }

    this.set("currentTarget", target);
  },

  @computed("currentTarget")
  currentTargetName(target) {
    switch(parseInt(target)) {
      case 0: return "common";
      case 1: return "desktop";
      case 2: return "mobile";
    }
  },

  @computed("fieldName")
  activeSectionMode(fieldName) {
    return fieldName && fieldName.indexOf("scss") > -1 ? "css" : "html";
  },

  @computed("fieldName", "currentTargetName", "model")
  activeSection: {
    get(fieldName, target, model) {
      return model.getField(target, fieldName);
    },
    set(value, fieldName, target, model) {
      model.setField(target, fieldName, value);
      return value;
    }
  },


  @computed("currentTarget")
  fields(target) {
    let fields = [
      "scss", "head_tag", "header", "after_header", "body_tag", "footer"
    ];

    if (parseInt(target) === 0) {
      fields.push("embedded_scss");
    }

    return fields.map(name=>{
      let hash = {
        key: (`admin.customize.theme.${name}.text`),
        name: name
      };

      if (name.indexOf("_tag") > 0) {
        hash.icon = "file-text-o";
      }

      hash.title = I18n.t(`admin.customize.theme.${name}.title`);

      return hash;
    });
  },

  previewUrl: url('model.key', '/?preview-style=%@'),

  maximizeIcon: function() {
    return this.get('maximized') ? 'compress' : 'expand';
  }.property('maximized'),

  saveButtonText: function() {
    return this.get('model.isSaving') ? I18n.t('saving') : I18n.t('admin.customize.save');
  }.property('model.isSaving'),

  saveDisabled: function() {
    return !this.get('model.changed') || this.get('model.isSaving');
  }.property('model.changed', 'model.isSaving'),

  undoPreviewUrl: url('/?preview-style='),
  defaultStyleUrl: url('/?preview-style=default'),

  actions: {
    save() {
      this.get('model').saveChanges("theme_fields");
    },

    toggleMaximize: function() {
      this.toggleProperty('maximized');
    }
  }

});
