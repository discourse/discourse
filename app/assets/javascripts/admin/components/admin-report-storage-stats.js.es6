import Component from "@ember/component";
import { setting } from "discourse/lib/computed";
import computed from "ember-addons/ember-computed-decorators";

export default Component.extend({
  classNames: ["admin-report-storage-stats"],

  backupLocation: setting("backup_location"),
  backupStats: Ember.computed.alias("model.data.backups"),
  uploadStats: Ember.computed.alias("model.data.uploads"),

  @computed("backupStats")
  showBackupStats(stats) {
    return stats && this.currentUser.admin;
  },

  @computed("backupLocation")
  backupLocationName(backupLocation) {
    return I18n.t(`admin.backups.location.${backupLocation}`);
  },

  @computed("backupStats.used_bytes")
  usedBackupSpace(bytes) {
    return I18n.toHumanSize(bytes);
  },

  @computed("backupStats.free_bytes")
  freeBackupSpace(bytes) {
    return I18n.toHumanSize(bytes);
  },

  @computed("uploadStats.used_bytes")
  usedUploadSpace(bytes) {
    return I18n.toHumanSize(bytes);
  },

  @computed("uploadStats.free_bytes")
  freeUploadSpace(bytes) {
    return I18n.toHumanSize(bytes);
  }
});
