import Controller from "@ember/controller";
import { action, computed, set } from "@ember/object";
import { filterBy, reads } from "@ember/object/computed";
import { schedule } from "@ember/runloop";
import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import { extractError } from "discourse/lib/ajax-error";
import I18n from "discourse-i18n";

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

  @action
  saveAutomation(routeToIndex = false) {
    this.setProperties({ error: null, isUpdatingAutomation: true });

    const updatedAutomationForm = {
      ...this.automationForm,
      name: this.automationForm.name,
    };

    return ajax(
      `/admin/plugins/discourse-automation/automations/${this.model.automation.id}.json`,
      {
        type: "PUT",
        data: JSON.stringify({ automation: updatedAutomationForm }),
        dataType: "json",
        contentType: "application/json",
      }
    )
      .then(() => {
        this.send("refreshRoute");
        if (routeToIndex) {
          this.router.transitionTo("adminPlugins.discourse-automation.index");
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
      message: I18n.t("discourse_automation.confirm_automation_reset"),
      didConfirm: () => {
        return callback && callback();
      },
    });
  }

  _confirmTrigger(callback) {
    this.dialog.yesNoConfirm({
      message: I18n.t("discourse_automation.confirm_automation_trigger"),
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
