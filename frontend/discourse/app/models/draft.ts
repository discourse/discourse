import EmberObject from "@ember/object";
import { ajax } from "discourse/lib/ajax";
import getURL from "discourse/lib/get-url";
import type { TopicBasicUser } from "discourse/models/topic";

export interface DraftGetResponse {
  draft: string | null;
  draft_sequence: number;
}

export interface DraftSaveResponse {
  success: "OK";
  draft_sequence: number;
  conflict_user?: TopicBasicUser;
}

export default class Draft extends EmberObject {
  static clear(key: string, sequence: number): Promise<{ success: "OK" }> {
    return ajax(`/drafts/${key}.json`, {
      type: "DELETE",
      data: { draft_key: key, sequence },
    });
  }

  static bulkClear(
    drafts: { draft_key: string; sequence: number }[]
  ): Promise<{ success: "OK"; deleted_count: number }> {
    const draft_keys = drafts.map((d) => d.draft_key);
    const sequences: Record<string, number> = {};
    drafts.forEach((d) => {
      sequences[d.draft_key] = d.sequence;
    });

    return ajax("/drafts/bulk_destroy.json", {
      type: "DELETE",
      data: { draft_keys, sequences },
    });
  }

  static get(key: string): Promise<DraftGetResponse> {
    return ajax(`/drafts/${key}.json`);
  }

  static getLocal<T>(key: string, current: T): T {
    // TODO: implement this
    return current;
  }

  static save(
    key: string,
    sequence: number,
    data: string | object,
    clientId: string,
    { forceSave = false }: { forceSave?: boolean } = {}
  ): Promise<DraftSaveResponse> {
    data = typeof data === "string" ? data : JSON.stringify(data);
    return ajax("/drafts.json", {
      type: "POST",
      data: {
        draft_key: key,
        sequence,
        data,
        owner: clientId,
        force_save: forceSave,
      },
      ignoreUnsent: false,
    });
  }

  static saveBeacon(
    key: string,
    sequence: number,
    data: string | object,
    clientId: string,
    csrfToken: string
  ): void {
    const formData = new FormData();
    formData.append("draft_key", key);
    // FormData coerces numeric sequences to strings at the existing browser boundary.
    formData.append("sequence", sequence as unknown as string);
    formData.append("data", JSON.stringify(data));
    formData.append("owner", clientId);
    formData.append("authenticity_token", csrfToken);
    navigator.sendBeacon(getURL("/drafts.json"), formData);
  }
}
