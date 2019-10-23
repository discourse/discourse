import Controller from "@ember/controller";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { extractDomainFromUrl } from "discourse/lib/utilities";
import computed from "ember-addons/ember-computed-decorators";
import InputValidation from "discourse/models/input-validation";

export default Controller.extend({
  adminWebHooks: Ember.inject.controller(),
  eventTypes: Ember.computed.alias("adminWebHooks.eventTypes"),
  defaultEventTypes: Ember.computed.alias("adminWebHooks.defaultEventTypes"),
  contentTypes: Ember.computed.alias("adminWebHooks.contentTypes"),

  @computed
  showTagsFilter() {
    return this.siteSettings.tagging_enabled;
  },

  @computed("model.isSaving", "saved", "saveButtonDisabled")
  savingStatus(isSaving, saved, saveButtonDisabled) {
    if (isSaving) {
      return I18n.t("saving");
    } else if (!saveButtonDisabled && saved) {
      return I18n.t("saved");
    }
    // Use side effect of validation to clear saved text
    this.set("saved", false);
    return "";
  },

  @computed("model.isNew")
  saveButtonText(isNew) {
    return isNew
      ? I18n.t("admin.web_hooks.create")
      : I18n.t("admin.web_hooks.save");
  },

  @computed("model.secret")
  secretValidation(secret) {
    if (!Ember.isEmpty(secret)) {
      if (secret.indexOf(" ") !== -1) {
        return InputValidation.create({
          failed: true,
          reason: I18n.t("admin.web_hooks.secret_invalid")
        });
      }

      if (secret.length < 12) {
        return InputValidation.create({
          failed: true,
          reason: I18n.t("admin.web_hooks.secret_too_short")
        });
      }
    }
  },

  @computed("model.wildcard_web_hook", "model.web_hook_event_types.[]")
  eventTypeValidation(isWildcard, eventTypes) {
    if (!isWildcard && Ember.isEmpty(eventTypes)) {
      return InputValidation.create({
        failed: true,
        reason: I18n.t("admin.web_hooks.event_type_missing")
      });
    }
  },

  @computed(
    "model.isSaving",
    "secretValidation",
    "eventTypeValidation",
    "model.payload_url"
  )
  saveButtonDisabled(
    isSaving,
    secretValidation,
    eventTypeValidation,
    payloadUrl
  ) {
    return isSaving
      ? false
      : secretValidation || eventTypeValidation || Ember.isEmpty(payloadUrl);
  },

  actions: {
    save() {
      this.set("saved", false);
      const url = this.get("model.payload_url");
      const domain = extractDomainFromUrl(url);
      const model = this.model;
      const isNew = model.get("isNew");

      const saveWebHook = () => {
        return model
          .save()
          .then(() => {
            this.set("saved", true);
            this.adminWebHooks.get("model").addObject(model);

            if (isNew) {
              this.transitionToRoute("adminWebHooks.show", model.get("id"));
            }
          })
          .catch(popupAjaxError);
      };

      if (
        domain === "localhost" ||
        domain.match(/192\.168\.\d+\.\d+/) ||
        domain.match(/127\.\d+\.\d+\.\d+/) ||
        url.startsWith(Discourse.BaseUrl)
      ) {
        return bootbox.confirm(
          I18n.t("admin.web_hooks.warn_local_payload_url"),
          I18n.t("no_value"),
          I18n.t("yes_value"),
          result => {
            if (result) {
              return saveWebHook();
            }
          }
        );
      }

      return saveWebHook();
    },

    destroy() {
      return bootbox.confirm(
        I18n.t("admin.web_hooks.delete_confirm"),
        I18n.t("no_value"),
        I18n.t("yes_value"),
        result => {
          if (result) {
            const model = this.model;
            model
              .destroyRecord()
              .then(() => {
                this.adminWebHooks.get("model").removeObject(model);
                this.transitionToRoute("adminWebHooks");
              })
              .catch(popupAjaxError);
          }
        }
      );
    }
  }
});
