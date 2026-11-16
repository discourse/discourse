import EmberObject from "@ember/object";
import { ajax } from "discourse/lib/ajax";

type MessageBusWindow = { MessageBus: { clientId: string } };

/** `/admin/backups` record. */
export interface BackupFields {
  filename: string;
  size: number;
  last_modified: string;
}

/** Operation endpoints answer `success_json`; failures reject. */
export interface BackupOperationResult {
  success?: string;
  failed?: string;
  message?: string;
}

// eslint-disable-next-line @typescript-eslint/no-empty-object-type, @typescript-eslint/no-unsafe-declaration-merging
export default interface Backup extends BackupFields {}

// eslint-disable-next-line @typescript-eslint/no-unsafe-declaration-merging
export default class Backup extends EmberObject {
  /** Resolves the plain records, not model instances. */
  static find(): Promise<BackupFields[]> {
    return ajax("/admin/backups.json");
  }

  static start(withUploads?: boolean): Promise<BackupOperationResult> {
    if (withUploads === undefined) {
      withUploads = true;
    }
    return ajax("/admin/backups", {
      type: "POST",
      data: {
        with_uploads: withUploads,
        // TODO(typescript-pending): the MessageBus global is untyped; remove this assertion when it is typed.
        client_id: (window as unknown as MessageBusWindow).MessageBus.clientId,
      },
    });
  }

  static cancel(): Promise<BackupOperationResult> {
    return ajax("/admin/backups/cancel.json", {
      type: "DELETE",
    });
  }

  static rollback(): Promise<BackupOperationResult> {
    return ajax("/admin/backups/rollback.json", {
      type: "POST",
    });
  }

  /** Deletes the backup file on the server, unlike EmberObject's `destroy`. */
  destroy(this: never): never;
  destroy(): Promise<unknown>;
  destroy(): Promise<unknown> {
    return ajax("/admin/backups/" + this.filename, { type: "DELETE" });
  }

  restore(): Promise<BackupOperationResult> {
    return ajax("/admin/backups/" + this.filename + "/restore", {
      type: "POST",
      // TODO(typescript-pending): the MessageBus global is untyped; remove this assertion when it is typed.
      data: {
        client_id: (window as unknown as MessageBusWindow).MessageBus.clientId,
      },
    });
  }
}
