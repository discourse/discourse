import Controller, { inject as controller } from "@ember/controller";
import EmberObject, { action } from "@ember/object";
import { alias } from "@ember/object/computed";
import { service } from "@ember/service";
import { isEmpty } from "@ember/utils";
import { popupAjaxError } from "discourse/lib/ajax-error";
import discourseComputed from "discourse-common/utils/decorators";
import { i18n } from "discourse-i18n";

export default class AdminWebHooksEditController extends Controller {
  @service dialog;
  @service router;
  @service siteSettings;

  @controller adminWebHooks;

  @alias("adminWebHooks.groupedEventTypes") groupedEventTypes;
  @alias("adminWebHooks.defaultEventTypes") defaultEventTypes;
  @alias("adminWebHooks.contentTypes") contentTypes;

  @discourseComputed
  showTagsFilter() {
    return this.siteSettings.tagging_enabled;
  }

  @discourseComputed("model.isSaving", "saved", "saveButtonDisabled")
  savingStatus(isSaving, saved, saveButtonDisabled) {
    if (isSaving) {
      return i18n("saving");
    } else if (!saveButtonDisabled && saved) {
      return i18n("saved");
    }
    // Use side effect of validation to clear saved text
    this.set("saved", false);
    return "";
  }

  @discourseComputed("model.isNew")
  saveButtonText(isNew) {
    return isNew
      ? i18n("admin.web_hooks.create")
      : i18n("admin.web_hooks.save");
  }

  @discourseComputed("model.secret")
  secretValidation(secret) {
    if (!isEmpty(secret)) {
      if (secret.includes(" ")) {
        return EmberObject.create({
          failed: true,
          reason: i18n("admin.web_hooks.secret_invalid"),
        });
      }

      if (secret.length < 12) {
        return EmberObject.create({
          failed: true,
          reason: i18n("admin.web_hooks.secret_too_short"),
        });
      }
    }
  }

  @discourseComputed("model.wildcard_web_hook", "model.web_hook_event_types.[]")
  eventTypeValidation(isWildcard, eventTypes) {
    if (!isWildcard && isEmpty(eventTypes)) {
      return EmberObject.create({
        failed: true,
        reason: i18n("admin.web_hooks.event_type_missing"),
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
      this.router.transitionTo("adminWebHooks.show", this.model);
    } catch (e) {
      popupAjaxError(e);
    }
  }
}
