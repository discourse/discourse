import { tracked } from "@glimmer/tracking";
import Controller from "@ember/controller";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { observes } from "@ember-decorators/object";
import ScreenedIpAddress from "discourse/admin/models/screened-ip-address";
import { removeValueFromArray } from "discourse/lib/array-tools";
import discourseDebounce from "discourse/lib/debounce";
import { INPUT_DELAY } from "discourse/lib/environment";
import { exportEntity } from "discourse/lib/export-csv";
import { outputExportResult } from "discourse/lib/export-result";
import { trackedArray } from "discourse/lib/tracked-tools";
import { i18n } from "discourse-i18n";

export default class AdminLogsScreenedIpAddressesController extends Controller {
  @service dialog;

  @tracked filter = null;
  @tracked loading = false;
  @tracked savedIpAddress = null;
  @trackedArray model;

  @observes("filter")
  show() {
    discourseDebounce(this, this.#debouncedShow, INPUT_DELAY);
  }

  @action
  edit(record, event) {
    event?.preventDefault();
    if (!record.get("editing")) {
      this.set("savedIpAddress", record.get("ip_address"));
    }
    record.set("editing", true);
  }

  @action
  allow(record) {
    record.set("action_name", "do_nothing");
    record.save();
  }

  @action
  block(record) {
    record.set("action_name", "block");
    record.save();
  }

  @action
  cancel(record) {
    const savedIpAddress = this.savedIpAddress;
    if (savedIpAddress && record.get("editing")) {
      record.set("ip_address", savedIpAddress);
    }
    record.set("editing", false);
  }

  @action
  save(record) {
    const wasEditing = record.get("editing");
    record.set("editing", false);
    record
      .save()
      .then(() => this.set("savedIpAddress", null))
      .catch((e) => {
        if (e.jqXHR.responseJSON && e.jqXHR.responseJSON.errors) {
          this.dialog.alert(
            i18n("generic_error_with_reason", {
              error: e.jqXHR.responseJSON.errors.join(". "),
            })
          );
        } else {
          this.dialog.alert(i18n("generic_error"));
        }
        if (wasEditing) {
          record.set("editing", true);
        }
      });
  }

  @action
  async destroyRecord(record) {
    return this.dialog.yesNoConfirm({
      message: i18n("admin.logs.screened_ips.delete_confirm", {
        ip_address: record.get("ip_address"),
      }),
      didConfirm: async () => {
        try {
          const deleted = await record.destroy();
          if (deleted) {
            removeValueFromArray(this.model, record);
          } else {
            this.dialog.alert(i18n("generic_error"));
          }
        } catch (e) {
          this.dialog.alert(
            i18n("generic_error_with_reason", {
              error: `http: ${e.status} - ${e.body}`,
            })
          );
        }
      },
    });
  }

  @action
  recordAdded(arg) {
    this.model.unshift(arg);
  }

  @action
  exportScreenedIpList() {
    exportEntity("screened_ip").then(outputExportResult);
  }

  async #debouncedShow() {
    this.loading = true;

    try {
      this.model = await ScreenedIpAddress.findAll(this.filter);
    } finally {
      this.loading = false;
    }
  }
}
