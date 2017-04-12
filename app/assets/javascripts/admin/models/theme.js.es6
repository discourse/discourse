import RestModel from 'discourse/models/rest';
import { default as computed } from 'ember-addons/ember-computed-decorators';

const Theme = RestModel.extend({

  @computed('theme_fields')
  themeFields(fields) {

    if (!fields) {
      this.set('theme_fields', []);
      return {};
    }

    let hash = {};
    if (fields) {
      fields.forEach(field=>{
        hash[field.target + " " + field.name] = field;
      });
    }
    return hash;
  },

  getField(target, name) {
    let themeFields = this.get("themeFields");
    let key = target + " " + name;
    let field = themeFields[key];
    return field ? field.value : "";
  },

  setField(target, name, value) {
    this.set("changed", true);

    let themeFields = this.get("themeFields");
    let key = target + " " + name;
    let field = themeFields[key];
    if (!field) {
      field = {name, target, value};
      this.theme_fields.push(field);
      themeFields[key] = field;
    } else {
      field.value = value;
    }
  },

  @computed("childThemes.@each")
  child_theme_ids(childThemes) {
    if (childThemes) {
      return childThemes.map(theme => Ember.get(theme, "id"));
    }
  },

  removeChildTheme(theme) {
    const childThemes = this.get("childThemes");
    childThemes.removeObject(theme);
    return this.saveChanges("child_theme_ids");
  },

  addChildTheme(theme){
    let childThemes = this.get("childThemes");
    childThemes.removeObject(theme);
    childThemes.pushObject(theme);
    return this.saveChanges("child_theme_ids");
  },

  @computed('name', 'default')
  description: function(name, isDefault) {
    if (isDefault) {
      return I18n.t('admin.customize.theme.default_name', {name: name});
    } else {
      return name;
    }
  },

  checkForUpdates() {
    return this.save({remote_check: true})
      .then(() => this.set("changed", false));
  },

  updateToLatest() {
    return this.save({remote_update: true})
      .then(() => this.set("changed", false));
  },

  changed: false,

  saveChanges() {
    const hash = this.getProperties.apply(this, arguments);
    return this.save(hash)
      .then(() => this.set("changed", false));
  },

});

export default Theme;
