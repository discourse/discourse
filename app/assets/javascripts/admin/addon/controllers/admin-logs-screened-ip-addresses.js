import Controller from "@ember/controller";
import I18n from "I18n";
import { INPUT_DELAY } from "discourse-common/config/environment";
import ScreenedIpAddress from "admin/models/screened-ip-address";
import bootbox from "bootbox";
import discourseDebounce from "discourse-common/lib/debounce";
import { exportEntity } from "discourse/lib/export-csv";
import { observes } from "discourse-common/utils/decorators";
import { outputExportResult } from "discourse/lib/export-result";

export default Controller.extend({
  loading: false,
  filter: null,
  savedIpAddress: null,

  _debouncedShow() {
    this.set("loading", true);
    ScreenedIpAddress.findAll(this.filter).then((result) => {
      this.setProperties({ model: result, loading: false });
    });
  },

  @observes("filter")
  show() {
    discourseDebounce(this, this._debouncedShow, INPUT_DELAY);
  },

  actions: {
    allow(record) {
      record.set("action_name", "do_nothing");
      record.save();
    },

    block(record) {
      record.set("action_name", "block");
      record.save();
    },

    edit(record) {
      if (!record.get("editing")) {
        this.set("savedIpAddress", record.get("ip_address"));
      }
      record.set("editing", true);
    },

    cancel(record) {
      const savedIpAddress = this.savedIpAddress;
      if (savedIpAddress && record.get("editing")) {
        record.set("ip_address", savedIpAddress);
      }
      record.set("editing", false);
    },

    save(record) {
      const wasEditing = record.get("editing");
      record.set("editing", false);
      record
        .save()
        .then(() => this.set("savedIpAddress", null))
        .catch((e) => {
          if (e.jqXHR.responseJSON && e.jqXHR.responseJSON.errors) {
            bootbox.alert(
              I18n.t("generic_error_with_reason", {
                error: e.jqXHR.responseJSON.errors.join(". "),
              })
            );
          } else {
            bootbox.alert(I18n.t("generic_error"));
          }
          if (wasEditing) {
            record.set("editing", true);
          }
        });
    },

    destroy(record) {
      return bootbox.confirm(
        I18n.t("admin.logs.screened_ips.delete_confirm", {
          ip_address: record.get("ip_address"),
        }),
        I18n.t("no_value"),
        I18n.t("yes_value"),
        (result) => {
          if (result) {
            record
              .destroy()
              .then((deleted) => {
                if (deleted) {
                  this.model.removeObject(record);
                } else {
                  bootbox.alert(I18n.t("generic_error"));
                }
              })
              .catch((e) => {
                bootbox.alert(
                  I18n.t("generic_error_with_reason", {
                    error: `http: ${e.status} - ${e.body}`,
                  })
                );
              });
          }
        }
      );
    },

    recordAdded(arg) {
      this.model.unshiftObject(arg);
    },

    exportScreenedIpList() {
      exportEntity("screened_ip").then(outputExportResult);
    },
  },
});
