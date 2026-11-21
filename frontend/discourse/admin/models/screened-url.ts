import EmberObject, { computed } from "@ember/object";
import { ajax } from "discourse/lib/ajax";
import { i18n } from "discourse-i18n";

/** `/admin/logs/screened_urls` row, grouped by domain; the grouped query always reports `do_nothing`. */
export interface ScreenedUrlFields {
  domain: string;
  action: "do_nothing";
  match_count: number;
  last_match_at: string | null;
  created_at: string;
}

// eslint-disable-next-line @typescript-eslint/no-empty-object-type, @typescript-eslint/no-unsafe-declaration-merging
export default interface ScreenedUrl extends ScreenedUrlFields {}

// eslint-disable-next-line @typescript-eslint/no-unsafe-declaration-merging
export default class ScreenedUrl extends EmberObject {
  static findAll(): Promise<ScreenedUrl[]> {
    return ajax("/admin/logs/screened_urls.json").then(function (
      screened_urls: ScreenedUrlFields[]
    ) {
      return screened_urls.map(function (b) {
        return ScreenedUrl.create(b);
      });
    });
  }

  @computed("action")
  get actionName(): string {
    return i18n("admin.logs.screened_actions." + this.action);
  }
}
