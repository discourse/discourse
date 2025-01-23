import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { notEmpty } from "@ember/object/computed";
import { service } from "@ember/service";
import ConditionalLoadingSpinner from "discourse/components/conditional-loading-spinner";
import DButton from "discourse/components/d-button";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { bind } from "discourse/lib/decorators";
import { exportEntity } from "discourse/lib/export-csv";
import { i18n } from "discourse-i18n";
import UserExport from "admin/models/user-export";

const EXPORT_PROGRESS_CHANNEL = "/user-export-progress";

export default class extends Component {
  @service dialog;
  @service messageBus;

  @tracked userExport = null;
  @tracked userExportReloading = false;

  @notEmpty("userExport") userExportAvailable;

  constructor() {
    super(...arguments);
    this.messageBus.subscribe(EXPORT_PROGRESS_CHANNEL, this.onExportProgress);

    this.model = this.args.model;
    this.userExport = UserExport.create(this.model.latest_export?.user_export);
  }

  willDestroy() {
    super.willDestroy(...arguments);
    this.messageBus.unsubscribe(EXPORT_PROGRESS_CHANNEL, this.onExportProgress);
  }

  @bind
  onExportProgress(data) {
    if (data.user_export_id === this.model.id) {
      this.userExportReloading = false;
      if (data.failed) {
        this.dialog.alert(i18n("admin.user.exports.download.export_failed"));
      } else {
        this.userExport = UserExport.create(data.export_data.user_export);
      }
    }
  }

  @action
  triggerUserExport() {
    this.dialog.yesNoConfirm({
      message: i18n("admin.user.exports.download.confirm"),
      didConfirm: async () => {
        this.userExportReloading = true;
        try {
          await exportEntity("user_archive", {
            export_user_id: this.model.id,
          });
          this.dialog.alert(i18n("admin.user.exports.download.success"));
        } catch (err) {
          popupAjaxError(err);
        }
      },
    });
  }

  get userExportExpiry() {
    return i18n("admin.user.exports.download.expires_in", {
      count: this.userExport.retain_hours,
    });
  }

  <template>
    <section class="details">
      <h1>{{i18n "admin.user.exports.title"}}</h1>

      <div class="display-row">
        <div class="field">{{i18n
            "admin.user.exports.download.description"
          }}</div>
        <div class="value">
          {{#if this.userExportAvailable}}
            <a
              class="download"
              href={{this.userExport.uri}}
            >{{this.userExport.filename}}</a><br />
            {{this.userExport.human_filesize}}<br />
            {{this.userExportExpiry}}
          {{else}}
            {{i18n "admin.user.exports.download.not_available"}}
          {{/if}}
        </div>
        <div class="controls">
          <ConditionalLoadingSpinner @condition={{this.userExportReloading}}>

            <DButton
              @action={{this.triggerUserExport}}
              @icon="download"
              @label="admin.user.exports.download.button"
              class="btn-default"
            />
          </ConditionalLoadingSpinner>
        </div>
      </div>
    </section>
  </template>
}
