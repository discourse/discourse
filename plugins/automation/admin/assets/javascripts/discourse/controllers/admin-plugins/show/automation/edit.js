import Controller from "@ember/controller";
import { action, computed, set } from "@ember/object";
import { filterBy, reads } from "@ember/object/computed";
import { schedule } from "@ember/runloop";
import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import { extractError, popupAjaxError } from "discourse/lib/ajax-error";
import { i18n } from "discourse-i18n";

export default class AutomationEdit extends Controller {
  @service dialog;
  @service router;

  error = null;
  isUpdatingAutomation = false;
  isTriggeringAutomation = false;

  @reads("model.automation") automation;
  @filterBy("automationForm.fields", "targetType", "script") scriptFields;
  @filterBy("automationForm.fields", "targetType", "trigger") triggerFields;

  @computed("model.automation.next_pending_automation_at")
  get nextPendingAutomationAtFormatted() {
    const date = this.model?.automation?.next_pending_automation_at;
    if (date) {
      return moment(date).format("LLLL");
    }
  }

  get disableEnabledToggle() {
    return !(this.automation.canBeEnabled || this.automation.enabled);
  }

  @action
  async toggleEnabled() {
    const automation = this.model.automation;
    automation.enabled = !automation.enabled;
    try {
      await automation.save({ enabled: automation.enabled });
    } catch (e) {
      popupAjaxError(e);
      automation.enabled = !automation.enabled;
    }
  }

  @action
  saveAutomation(routeToIndex = false) {
    this.setProperties({ error: null, isUpdatingAutomation: true });

    return ajax(
      `/admin/plugins/automation/automations/${this.model.automation.id}.json`,
      {
        type: "PUT",
        data: JSON.stringify({ automation: this.automationForm }),
        dataType: "json",
        contentType: "application/json",
      }
    )
      .then(() => {
        this.send("refreshRoute");
        if (routeToIndex) {
          this.router.transitionTo("adminPlugins.show.automation.index");
        }
      })
      .catch((e) => this._showError(e))
      .finally(() => {
        this.set("isUpdatingAutomation", false);
      });
  }

  @action
  onChangeTrigger(id) {
    if (this.automationForm.trigger && this.automationForm.trigger !== id) {
      this._confirmReset(() => {
        set(this.automationForm, "trigger", id);
        this.saveAutomation();
      });
    } else if (!this.automationForm.trigger) {
      set(this.automationForm, "trigger", id);
      this.saveAutomation();
    }
  }

  @action
  onManualAutomationTrigger(id) {
    this._confirmTrigger(() => {
      this.set("isTriggeringAutomation", true);

      return ajax(`/automations/${id}/trigger.json`, {
        type: "post",
      })
        .catch((e) => this.set("error", extractError(e)))
        .finally(() => {
          this.set("isTriggeringAutomation", false);
        });
    });
  }

  @action
  onChangeScript(id) {
    if (this.automationForm.script !== id) {
      this._confirmReset(() => {
        set(this.automationForm, "script", id);
        this.saveAutomation();
      });
    }
  }

  _confirmReset(callback) {
    this.dialog.yesNoConfirm({
      message: i18n("discourse_automation.confirm_automation_reset"),
      didConfirm: () => {
        return callback && callback();
      },
    });
  }

  _confirmTrigger(callback) {
    this.dialog.yesNoConfirm({
      message: i18n("discourse_automation.confirm_automation_trigger"),
      didConfirm: () => {
        return callback && callback();
      },
    });
  }

  _showError(error) {
    this.set("error", extractError(error));

    schedule("afterRender", () => {
      window.scrollTo(0, 0);
    });
  }
}
