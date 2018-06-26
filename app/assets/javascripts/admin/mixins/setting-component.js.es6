import computed from "ember-addons/ember-computed-decorators";
import { categoryLinkHTML } from "discourse/helpers/category-link";

const CUSTOM_TYPES = [
  "bool",
  "enum",
  "list",
  "url_list",
  "host_list",
  "category_list",
  "value_list",
  "category"
];

export default Ember.Mixin.create({
  classNameBindings: [":row", ":setting", "setting.overridden", "typeClass"],
  content: Ember.computed.alias("setting"),
  validationMessage: null,
  isSecret: Ember.computed.oneWay("setting.secret"),

  @computed("buffered.value", "setting.value")
  dirty(bufferVal, settingVal) {
    if (bufferVal === null || bufferVal === undefined) bufferVal = "";
    if (settingVal === null || settingVal === undefined) settingVal = "";

    return bufferVal.toString() !== settingVal.toString();
  },

  @computed("setting", "buffered.value")
  preview(setting, value) {
    // A bit hacky, but allows us to use helpers
    if (setting.get("setting") === "category_style") {
      let category = this.site.get("categories.firstObject");
      if (category) {
        return categoryLinkHTML(category, {
          categoryStyle: value
        });
      }
    }

    let preview = setting.get("preview");
    if (preview) {
      return new Handlebars.SafeString(
        "<div class='preview'>" +
          preview.replace(/\{\{value\}\}/g, value) +
          "</div>"
      );
    }
  },

  @computed("componentType")
  typeClass(componentType) {
    return componentType.replace(/\_/g, "-");
  },

  @computed("setting.setting")
  settingName(setting) {
    return setting.replace(/\_/g, " ");
  },

  @computed("setting.type")
  componentType(type) {
    return CUSTOM_TYPES.indexOf(type) !== -1 ? type : "string";
  },

  @computed("typeClass")
  componentName(typeClass) {
    return "site-settings/" + typeClass;
  },

  _watchEnterKey: function() {
    const self = this;
    this.$().on("keydown.setting-enter", ".input-setting-string", function(e) {
      if (e.keyCode === 13) {
        // enter key
        self._save();
      }
    });
  }.on("didInsertElement"),

  _removeBindings: function() {
    this.$().off("keydown.setting-enter");
  }.on("willDestroyElement"),

  _save() {
    Em.warn("You should define a `_save` method", {
      id: "admin.mixins.setting-component"
    });
    return Ember.RSVP.resolve();
  },

  actions: {
    save() {
      this._save()
        .then(() => {
          this.set("validationMessage", null);
          this.commitBuffer();
        })
        .catch(e => {
          if (e.jqXHR.responseJSON && e.jqXHR.responseJSON.errors) {
            this.set("validationMessage", e.jqXHR.responseJSON.errors[0]);
          } else {
            this.set("validationMessage", I18n.t("generic_error"));
          }
        });
    },

    cancel() {
      this.rollbackBuffer();
    },

    resetDefault() {
      this.set("buffered.value", this.get("setting.default"));
      this._save();
    },

    toggleSecret() {
      this.toggleProperty("isSecret");
    }
  }
});
