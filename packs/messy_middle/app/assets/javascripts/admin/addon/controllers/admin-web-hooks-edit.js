import { inject as service } from "@ember/service";
import { alias } from "@ember/object/computed";
import Controller, { inject as controller } from "@ember/controller";
import EmberObject, { action } from "@ember/object";
import I18n from "I18n";
import discourseComputed from "discourse-common/utils/decorators";
import { isEmpty } from "@ember/utils";
import { popupAjaxError } from "discourse/lib/ajax-error";

export default class AdminWebHooksEditController extends Controller {
  @service dialog;
  @controller adminWebHooks;

  @alias("adminWebHooks.eventTypes") eventTypes;
  @alias("adminWebHooks.defaultEventTypes") defaultEventTypes;
  @alias("adminWebHooks.contentTypes") contentTypes;

  @discourseComputed
  showTagsFilter() {
    return this.siteSettings.tagging_enabled;
  }

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
  }

  @discourseComputed("model.isNew")
  saveButtonText(isNew) {
    return isNew
      ? I18n.t("admin.web_hooks.create")
      : I18n.t("admin.web_hooks.save");
  }

  @discourseComputed("model.secret")
  secretValidation(secret) {
    if (!isEmpty(secret)) {
      if (secret.includes(" ")) {
        return EmberObject.create({
          failed: true,
          reason: I18n.t("admin.web_hooks.secret_invalid"),
        });
      }

      if (secret.length < 12) {
        return EmberObject.create({
          failed: true,
          reason: I18n.t("admin.web_hooks.secret_too_short"),
        });
      }
    }
  }

  @discourseComputed("model.wildcard_web_hook", "model.web_hook_event_types.[]")
  eventTypeValidation(isWildcard, eventTypes) {
    if (!isWildcard && isEmpty(eventTypes)) {
      return EmberObject.create({
        failed: true,
        reason: I18n.t("admin.web_hooks.event_type_missing"),
      });
    }
  }

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
  }

  @action
  async save() {
    this.set("saved", false);

    try {
      await this.model.save();

      this.set("saved", true);
      this.adminWebHooks.model.addObject(this.model);
      this.transitionToRoute("adminWebHooks.show", this.model);
    } catch (e) {
      popupAjaxError(e);
    }
  }
}
