import { url } from 'discourse/lib/computed';
import { default as computed, observes } from 'ember-addons/ember-computed-decorators';

export default Ember.Controller.extend({
  maximized: false,
  section: null,

  targets: [
    {id: 0, name: I18n.t('admin.customize.theme.common')},
    {id: 1, name: I18n.t('admin.customize.theme.desktop')},
    {id: 2, name: I18n.t('admin.customize.theme.mobile')}
  ],

  @computed('onlyOverridden')
  showCommon() {
    return this.shouldShow('common');
  },

  @computed('onlyOverridden')
  showDesktop() {
    return this.shouldShow('desktop');
  },

  @computed('onlyOverridden')
  showMobile() {
    return this.shouldShow('mobile');
  },

  @observes('onlyOverridden')
  onlyOverriddenChanged() {
    if (this.get('onlyOverridden')) {
      if (!this.get('model').hasEdited(this.get('currentTargetName'), this.get('fieldName'))) {
        let target = (this.get('showCommon') && 'common') ||
          (this.get('showDesktop') && 'desktop') ||
          (this.get('showMobile') && 'mobile');

        let fields = this.get('model.theme_fields');
        let field = fields && fields.find(f => (f.target === target));
        this.replaceRoute('adminCustomizeThemes.edit', this.get('model.id'), target, field && field.name);
      }
    }
  },

  shouldShow(target){
    if(!this.get("onlyOverridden")) {
      return true;
    }
    return this.get("model").hasEdited(target);
  },

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
    return fieldName && fieldName.indexOf("scss") > -1 ? "scss" : "html";
  },

  @computed("currentTargetName", "fieldName", "saving")
  error(target, fieldName) {
    return this.get('model').getError(target, fieldName);
  },

  @computed("fieldName", "currentTargetName")
  editorId(fieldName, currentTarget) {
    return fieldName + "|" + currentTarget;
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

  @computed("currentTarget", "onlyOverridden")
  fields(target, onlyOverridden) {
    let fields = [
      "scss", "head_tag", "header", "after_header", "body_tag", "footer"
    ];

    if (parseInt(target) === 0) {
      fields.push("embedded_scss");
    }

    if (onlyOverridden) {
      const model = this.get("model");
      const targetName = this.get("currentTargetName");
      fields = fields.filter(name => model.hasEdited(targetName, name));
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

  previewUrl: url('model.id', '/admin/themes/%@/preview'),

  maximizeIcon: function() {
    return this.get('maximized') ? 'compress' : 'expand';
  }.property('maximized'),

  saveButtonText: function() {
    return this.get('model.isSaving') ? I18n.t('saving') : I18n.t('admin.customize.save');
  }.property('model.isSaving'),

  saveDisabled: function() {
    return !this.get('model.changed') || this.get('model.isSaving');
  }.property('model.changed', 'model.isSaving'),

  actions: {
    save() {
      this.set('saving', true);
      this.get('model').saveChanges("theme_fields").finally(()=>{this.set('saving', false);});
    },

    toggleMaximize: function() {
      this.toggleProperty('maximized');
      Em.run.next(()=>{
        this.appEvents.trigger('ace:resize');
      });
    }
  }

});
