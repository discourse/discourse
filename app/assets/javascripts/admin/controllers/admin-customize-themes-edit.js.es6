import { url } from "discourse/lib/computed";
import {
  default as computed,
  observes
} from "ember-addons/ember-computed-decorators";

export default Ember.Controller.extend({
  section: null,
  currentTarget: 0,
  maximized: false,
  previewUrl: url("model.id", "/admin/themes/%@/preview"),

  editRouteName: "adminCustomizeThemes.edit",

  targets: [
    { id: 0, name: "common" },
    { id: 1, name: "desktop" },
    { id: 2, name: "mobile" },
    { id: 3, name: "settings" },
    { id: 4, name: "translations" }
  ],

  fieldsForTarget: function(target) {
    const common = [
      "scss",
      "head_tag",
      "header",
      "after_header",
      "body_tag",
      "footer"
    ];
    switch (target) {
      case "common":
        return [...common, "embedded_scss"];
      case "desktop":
        return common;
      case "mobile":
        return common;
      case "settings":
        return ["yaml"];
    }
  },

  @computed("onlyOverridden")
  showCommon() {
    return this.shouldShow("common");
  },

  @computed("onlyOverridden")
  showDesktop() {
    return this.shouldShow("desktop");
  },

  @computed("onlyOverridden")
  showMobile() {
    return this.shouldShow("mobile");
  },

  @observes("onlyOverridden")
  onlyOverriddenChanged() {
    if (this.get("onlyOverridden")) {
      if (
        !this.get("model").hasEdited(
          this.get("currentTargetName"),
          this.get("fieldName")
        )
      ) {
        let target =
          (this.get("showCommon") && "common") ||
          (this.get("showDesktop") && "desktop") ||
          (this.get("showMobile") && "mobile");

        let fields = this.get("model.theme_fields");
        let field = fields && fields.find(f => f.target === target);
        this.replaceRoute(
          this.get("editRouteName"),
          this.get("model.id"),
          target,
          field && field.name
        );
      }
    }
  },

  shouldShow(target) {
    if (!this.get("onlyOverridden")) {
      return true;
    }
    return this.get("model").hasEdited(target);
  },

  setTargetName: function(name) {
    const target = this.get("targets").find(t => t.name === name);
    this.set("currentTarget", target && target.id);
  },

  @computed("currentTarget")
  currentTargetName(id) {
    const target = this.get("targets").find(t => t.id === parseInt(id, 10));
    return target && target.name;
  },

  @computed("fieldName")
  activeSectionMode(fieldName) {
    if (fieldName === "yaml") return "yaml";
    return fieldName && fieldName.indexOf("scss") > -1 ? "scss" : "html";
  },

  @computed("currentTargetName", "fieldName", "saving")
  error(target, fieldName) {
    return this.get("model").getError(target, fieldName);
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

  @computed("currentTargetName", "onlyOverridden")
  fields(target, onlyOverridden) {
    let fields = this.fieldsForTarget(target);

    if (onlyOverridden) {
      const model = this.get("model");
      const targetName = this.get("currentTargetName");
      fields = fields.filter(name => model.hasEdited(targetName, name));
    }

    return fields.map(name => {
      let hash = {
        key: `admin.customize.theme.${name}.text`,
        name: name
      };

      if (name.indexOf("_tag") > 0) {
        hash.icon = "file-text-o";
      }

      hash.title = I18n.t(`admin.customize.theme.${name}.title`);

      return hash;
    });
  },

  @computed("maximized")
  maximizeIcon(maximized) {
    return maximized ? "discourse-compress" : "discourse-expand";
  },

  @computed("model.isSaving")
  saveButtonText(isSaving) {
    return isSaving ? I18n.t("saving") : I18n.t("admin.customize.save");
  },

  @computed("model.changed", "model.isSaving")
  saveDisabled(changed, isSaving) {
    return !changed || isSaving;
  },

  actions: {
    save() {
      this.set("saving", true);
      this.get("model")
        .saveChanges("theme_fields")
        .finally(() => {
          this.set("saving", false);
        });
    },

    toggleMaximize: function() {
      this.toggleProperty("maximized");
      Ember.run.next(() => {
        this.appEvents.trigger("ace:resize");
      });
    }
  }
});
