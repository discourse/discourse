import { classNames } from "@ember-decorators/component";
import { alias } from "@ember/object/computed";
import Component from "@ember/component";
import I18n from "I18n";
import discourseComputed from "discourse-common/utils/decorators";
import { setting } from "discourse/lib/computed";

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
    return I18n.t(`admin.backups.location.${backupLocation}`);
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
}
