import EmberObject, { computed } from "@ember/object";

/** Built from the backup operations status, camelCased by the backups route. */
export interface BackupStatusFields {
  isOperationRunning: boolean;
  canRollback: boolean;
  allowRestore: boolean;
}

// eslint-disable-next-line @typescript-eslint/no-empty-object-type, @typescript-eslint/no-unsafe-declaration-merging
export default interface BackupStatus extends BackupStatusFields {}

// eslint-disable-next-line @typescript-eslint/no-unsafe-declaration-merging
export default class BackupStatus extends EmberObject {
  @computed("restoreEnabled")
  get restoreDisabled(): boolean {
    return !this.restoreEnabled;
  }

  @computed("allowRestore", "isOperationRunning")
  get restoreEnabled(): boolean {
    return this.allowRestore && !this.isOperationRunning;
  }
}
