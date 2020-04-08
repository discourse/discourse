import discourseComputed from "discourse-common/utils/decorators";
import { alias } from "@ember/object/computed";
import Component from "@ember/component";
import { setting } from "discourse/lib/computed";

export default Component.extend({
  classNames: ["admin-report-storage-stats"],

  backupLocation: setting("backup_location"),
  backupStats: alias("model.data.backups"),
  uploadStats: alias("model.data.uploads"),

  @discourseComputed("backupStats")
  showBackupStats(stats) {
    return stats && this.currentUser.admin;
  },

  @discourseComputed("backupLocation")
  backupLocationName(backupLocation) {
    return I18n.t(`admin.backups.location.${backupLocation}`);
  },

  @discourseComputed("backupStats.used_bytes")
  usedBackupSpace(bytes) {
    return I18n.toHumanSize(bytes);
  },

  @discourseComputed("backupStats.free_bytes")
  freeBackupSpace(bytes) {
    return I18n.toHumanSize(bytes);
  },

  @discourseComputed("uploadStats.used_bytes")
  usedUploadSpace(bytes) {
    return I18n.toHumanSize(bytes);
  },

  @discourseComputed("uploadStats.free_bytes")
  freeUploadSpace(bytes) {
    return I18n.toHumanSize(bytes);
  }
});
