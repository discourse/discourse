import Component from "@ember/component";
import { alias } from "@ember/object/computed";
import { classNames } from "@ember-decorators/component";
import icon from "discourse/helpers/d-icon";
import formatDate from "discourse/helpers/format-date";
import getUrl from "discourse/helpers/get-url";
import htmlSafe from "discourse/helpers/html-safe";
import { setting } from "discourse/lib/computed";
import discourseComputed from "discourse/lib/decorators";
import I18n, { i18n } from "discourse-i18n";

@classNames("admin-report-storage-stats")
export default class AdminReportStorageStats extends Component {
  @setting("backup_location") backupLocation;

  @alias("model.data.backups") backupStats;

  @alias("model.data.uploads") uploadStats;

  @discourseComputed("backupStats")
  showBackupStats(stats) {
    return stats && this.currentUser.admin;
  }

  @discourseComputed("backupLocation")
  backupLocationName(backupLocation) {
    return i18n(`admin.backups.location.${backupLocation}`);
  }

  @discourseComputed("backupStats.used_bytes")
  usedBackupSpace(bytes) {
    return I18n.toHumanSize(bytes);
  }

  @discourseComputed("backupStats.free_bytes")
  freeBackupSpace(bytes) {
    return I18n.toHumanSize(bytes);
  }

  @discourseComputed("uploadStats.used_bytes")
  usedUploadSpace(bytes) {
    return I18n.toHumanSize(bytes);
  }

  @discourseComputed("uploadStats.free_bytes")
  freeUploadSpace(bytes) {
    return I18n.toHumanSize(bytes);
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
