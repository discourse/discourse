import { next } from "@ember/runloop";
import Component from "@ember/component";
import { default as computed } from "ember-addons/ember-computed-decorators";
import { fmt } from "discourse/lib/computed";

export default Component.extend({
  @computed("theme.targets", "onlyOverridden", "showAdvanced")
  visibleTargets(targets, onlyOverridden, showAdvanced) {
    return targets.filter(target => {
      if (target.advanced && !showAdvanced) {
        return false;
      }
      if (!onlyOverridden) {
        return true;
      }
      return target.edited;
    });
  },

  @computed("currentTargetName", "onlyOverridden", "theme.fields")
  visibleFields(targetName, onlyOverridden, fields) {
    fields = fields[targetName];
    if (onlyOverridden) {
      fields = fields.filter(field => field.edited);
    }
    return fields;
  },

  @computed("currentTargetName", "fieldName")
  activeSectionMode(targetName, fieldName) {
    if (["settings", "translations"].includes(targetName)) return "yaml";
    if (["extra_scss"].includes(targetName)) return "scss";
    return fieldName && fieldName.indexOf("scss") > -1 ? "scss" : "html";
  },

  @computed("fieldName", "currentTargetName", "theme")
  activeSection: {
    get(fieldName, target, model) {
      return model.getField(target, fieldName);
    },
    set(value, fieldName, target, model) {
      model.setField(target, fieldName, value);
      return value;
    }
  },

  editorId: fmt("fieldName", "currentTargetName", "%@|%@"),

  @computed("maximized")
  maximizeIcon(maximized) {
    return maximized ? "discourse-compress" : "discourse-expand";
  },

  @computed("currentTargetName", "theme.targets")
  showAddField(currentTargetName, targets) {
    return targets.find(t => t.name === currentTargetName).customNames;
  },

  @computed("currentTargetName", "fieldName", "theme.theme_fields.@each.error")
  error(target, fieldName) {
    return this.theme.getError(target, fieldName);
  },

  actions: {
    toggleShowAdvanced() {
      this.toggleProperty("showAdvanced");
    },

    toggleAddField() {
      this.toggleProperty("addingField");
    },

    cancelAddField() {
      this.set("addingField", false);
    },

    addField(name) {
      if (!name) return;
      name = name.replace(/[^a-zA-Z0-9-_/]/g, "");
      this.theme.setField(this.currentTargetName, name, "");
      this.setProperties({ newFieldName: "", addingField: false });
      this.fieldAdded(this.currentTargetName, name);
    },

    toggleMaximize: function() {
      this.toggleProperty("maximized");
      next(() => this.appEvents.trigger("ace:resize"));
    },

    onlyOverriddenChanged(value) {
      this.onlyOverriddenChanged(value);
    }
  }
});
