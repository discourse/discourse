import discourseComputed from "discourse-common/utils/decorators";
import { isEmpty } from "@ember/utils";
import { alias } from "@ember/object/computed";
import { inject } from "@ember/controller";
import Controller from "@ember/controller";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { extractDomainFromUrl } from "discourse/lib/utilities";
import EmberObject from "@ember/object";

export default Controller.extend({
  adminWebHooks: inject(),
  eventTypes: alias("adminWebHooks.eventTypes"),
  defaultEventTypes: alias("adminWebHooks.defaultEventTypes"),
  contentTypes: alias("adminWebHooks.contentTypes"),

  @discourseComputed
  showTagsFilter() {
    return this.siteSettings.tagging_enabled;
  },

  @discourseComputed("model.isSaving", "saved", "saveButtonDisabled")
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

  @discourseComputed("model.isNew")
  saveButtonText(isNew) {
    return isNew
      ? I18n.t("admin.web_hooks.create")
      : I18n.t("admin.web_hooks.save");
  },

  @discourseComputed("model.secret")
  secretValidation(secret) {
    if (!isEmpty(secret)) {
      if (secret.indexOf(" ") !== -1) {
        return EmberObject.create({
          failed: true,
          reason: I18n.t("admin.web_hooks.secret_invalid")
        });
      }

      if (secret.length < 12) {
        return EmberObject.create({
          failed: true,
          reason: I18n.t("admin.web_hooks.secret_too_short")
        });
      }
    }
  },

  @discourseComputed("model.wildcard_web_hook", "model.web_hook_event_types.[]")
  eventTypeValidation(isWildcard, eventTypes) {
    if (!isWildcard && isEmpty(eventTypes)) {
      return EmberObject.create({
        failed: true,
        reason: I18n.t("admin.web_hooks.event_type_missing")
      });
    }
  },

  @discourseComputed(
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
      : secretValidation || eventTypeValidation || isEmpty(payloadUrl);
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
