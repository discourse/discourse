/* eslint-disable ember/no-classic-components */
import Component from "@ember/component";
import { computed } from "@ember/object";
import { alias } from "@ember/object/computed";
import { htmlSafe } from "@ember/template";
import { classNames } from "@ember-decorators/component";
import icon from "discourse/helpers/d-icon";
import formatDate from "discourse/helpers/format-date";
import { setting } from "discourse/lib/computed";
import getUrl from "discourse/lib/get-url";
import I18n, { i18n } from "discourse-i18n";

@classNames("admin-report-storage-stats")
export default class AdminReportStorageStats extends Component {
  @setting("backup_location") backupLocation;

  @alias("model.data.backups") backupStats;

  @alias("model.data.uploads") uploadStats;

  @computed("backupStats")
  get showBackupStats() {
    return this.backupStats && this.currentUser.admin;
  }

  @computed("backupLocation")
  get backupLocationName() {
    return i18n(`admin.backups.location.${this.backupLocation}`);
  }

  @computed("backupStats.used_bytes")
  get usedBackupSpace() {
    return I18n.toHumanSize(this.backupStats?.used_bytes);
  }

  @computed("backupStats.free_bytes")
  get freeBackupSpace() {
    return I18n.toHumanSize(this.backupStats?.free_bytes);
  }

  @computed("uploadStats.used_bytes")
  get usedUploadSpace() {
    return I18n.toHumanSize(this.uploadStats?.used_bytes);
  }

  @computed("uploadStats.free_bytes")
  get freeUploadSpace() {
    return I18n.toHumanSize(this.uploadStats?.free_bytes);
  }

  <template>
    {{#if this.showBackupStats}}
      <div class="backups">
        <h3 class="storage-stats-title">
          <a href={{getUrl "/admin/backups"}}>{{icon "box-archive"}}
            {{i18n "admin.dashboard.backups"}}</a>
        </h3>
        <p>
          {{#if this.backupStats.free_bytes}}
            {{i18n
              "admin.dashboard.space_used_and_free"
              usedSize=this.usedBackupSpace
              freeSize=this.freeBackupSpace
            }}
          {{else}}
            {{i18n "admin.dashboard.space_used" usedSize=this.usedBackupSpace}}
          {{/if}}

          <br />
          {{i18n
            "admin.dashboard.backup_count"
            count=this.backupStats.count
            location=this.backupLocationName
          }}

          {{#if this.backupStats.last_backup_taken_at}}
            <br />
            {{htmlSafe
              (i18n
                "admin.dashboard.lastest_backup"
                date=(formatDate
                  this.backupStats.last_backup_taken_at leaveAgo="true"
                )
              )
            }}
          {{/if}}
        </p>
      </div>
    {{/if}}

    <div class="uploads">
      <h3 class="storage-stats-title">{{icon "upload"}}
        {{i18n "admin.dashboard.uploads"}}</h3>
      <p>
        {{#if this.uploadStats.free_bytes}}
          {{i18n
            "admin.dashboard.space_used_and_free"
            usedSize=this.usedUploadSpace
            freeSize=this.freeUploadSpace
          }}
        {{else}}
          {{i18n "admin.dashboard.space_used" usedSize=this.usedUploadSpace}}
        {{/if}}
      </p>
    </div>
  </template>
}
