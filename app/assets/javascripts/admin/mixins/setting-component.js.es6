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
  "category",
  "uploaded_image_list",
  "compact_list",
  "secret_list",
  "upload"
];

export default Ember.Mixin.create({
  classNameBindings: [":row", ":setting", "overridden", "typeClass"],
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

  @computed("type")
  componentType(type) {
    return CUSTOM_TYPES.indexOf(type) !== -1 ? type : "string";
  },

  @computed("setting")
  type(setting) {
    if (setting.type === "list" && setting.list_type) {
      return `${setting.list_type}_list`;
    }

    return setting.type;
  },

  @computed("typeClass")
  componentName(typeClass) {
    return "site-settings/" + typeClass;
  },

  @computed("setting.default", "buffered.value")
  overridden(settingDefault, bufferedValue) {
    return settingDefault !== bufferedValue;
  },

  _watchEnterKey: function() {
    this.$().on("keydown.setting-enter", ".input-setting-string", e => {
      if (e.keyCode === 13) {
        // enter key
        this.send("save");
      }
    });
  }.on("didInsertElement"),

  _removeBindings: function() {
    this.$().off("keydown.setting-enter");
  }.on("willDestroyElement"),

  _save() {
    Ember.warn("You should define a `_save` method", {
      id: "discourse.setting-component.missing-save"
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
    },

    toggleSecret() {
      this.toggleProperty("isSecret");
    }
  }
});
