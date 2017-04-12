import { default as computed } from 'ember-addons/ember-computed-decorators';
import { url } from 'discourse/lib/computed';

export default Ember.Controller.extend({

  @computed("model.theme_fields.@each")
  hasEditedFields(fields) {
    return fields.any(f=>!Em.isBlank(f.value));
  },

  @computed('model.theme_fields.@each')
  editedDescriptions(fields) {
    let descriptions = [];
    let description = target => {
      let current = fields.filter(field => field.target === target && !Em.isBlank(field.value));
      if (current.length > 0) {
        let text = I18n.t('admin.customize.theme.'+target);
        let localized = current.map(f=>I18n.t('admin.customize.theme.'+f.name + '.text'));
        return text + ": " + localized.join(" , ");
      }
    };
    ['common','desktop','mobile'].forEach(target=> {
      descriptions.push(description(target));
    });
    return descriptions.reject(d=>Em.isBlank(d));
  },

  @computed("colorSchemeId", "model.color_scheme_id")
  colorSchemeChanged(colorSchemeId, existingId) {
    colorSchemeId = colorSchemeId === null ? null : parseInt(colorSchemeId);
    return  colorSchemeId !== existingId;
  },

  @computed("availableChildThemes", "model.childThemes.@each", "model", "allowChildThemes")
  selectableChildThemes(available, childThemes, model, allowChildThemes) {
    if (!allowChildThemes && (!childThemes || childThemes.length === 0)) {
      return null;
    }

    let themes = [];
    available.forEach(t=> {
      if (!childThemes || (childThemes.indexOf(t) === -1)) {
        themes.push(t);
      };
    });
    return themes.length === 0 ? null : themes;
  },

  showSchemes: Em.computed.or("model.default", "model.user_selectable"),

  @computed("allThemes", "allThemes.length", "model")
  availableChildThemes(allThemes, count) {
    if (count === 1) {
      return null;
    }

    let excludeIds = [this.get("model.id")];

    let themes = [];
    allThemes.forEach(theme => {
      if (excludeIds.indexOf(theme.get("id")) === -1) {
        themes.push(theme);
      }
    });

    return themes;
  },

  downloadUrl: url('model.id', '/admin/themes/%@'),

  actions: {

    updateToLatest() {
      this.set("updatingRemote", true);
      this.get("model").updateToLatest().finally(()=>{
        this.set("updatingRemote", false);
      });
    },

    checkForThemeUpdates() {
      this.set("updatingRemote", true);
      this.get("model").checkForUpdates().finally(()=>{
        this.set("updatingRemote", false);
      });
    },

    cancelChangeScheme() {
      this.set("colorSchemeId", this.get("model.color_scheme_id"));
    },
    changeScheme(){
      let schemeId = this.get("colorSchemeId");
      this.set("model.color_scheme_id", schemeId === null ? null : parseInt(schemeId));
      this.get("model").saveChanges("color_scheme_id");
    },
    startEditingName() {
      this.set("oldName", this.get("model.name"));
      this.set("editingName", true);
    },
    cancelEditingName() {
      this.set("model.name", this.get("oldName"));
      this.set("editingName", false);
    },
    finishedEditingName() {
      this.get("model").saveChanges("name");
      this.set("editingName", false);
    },

    editTheme() {
      let edit = ()=>this.transitionToRoute('adminCustomizeThemes.edit', {model: this.get('model')});

      if (this.get("model.remote_theme")) {
      bootbox.confirm(I18n.t("admin.customize.theme.edit_confirm"), result => {
        if (result) {
          edit();
        }
      });
      } else {
        edit();
      }
    },

    applyDefault() {
      const model = this.get("model");
      model.saveChanges("default").then(()=>{
        if (model.get("default")) {
          this.get("allThemes").forEach(theme=>{
            if (theme !== model && theme.get('default')) {
              theme.set("default", false);
            }
          });
        }
      });
    },

    applyUserSelectable() {
      this.get("model").saveChanges("user_selectable");
    },

    addChildTheme() {
      let themeId = parseInt(this.get("selectedChildThemeId"));
      let theme = this.get("allThemes").findBy("id", themeId);
      this.get("model").addChildTheme(theme);
    },

    removeChildTheme(theme) {
      this.get("model").removeChildTheme(theme);
    },

    destroy() {
      return bootbox.confirm(I18n.t("admin.customize.delete_confirm"), I18n.t("no_value"), I18n.t("yes_value"), result => {
        if (result) {
          const model = this.get('model');
          model.destroyRecord().then(() => {
            this.get('allThemes').removeObject(model);
            this.transitionToRoute('adminCustomizeThemes');
          });
        }
      });
    },

  }

});
