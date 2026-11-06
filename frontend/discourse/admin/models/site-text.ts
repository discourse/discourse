import { getProperties } from "@ember/object";
import { ajax } from "discourse/lib/ajax";
import RestModel from "discourse/models/rest";

/** `/admin/customize/site_texts` record, keyed by its translation key. */
export interface SiteTextFields {
  id: string;
  value: string;
  status:
    | "up_to_date"
    | "outdated"
    | "invalid_interpolation_keys"
    | "deprecated";
  old_default: string | null;
  new_default: string | null;
  interpolation_keys: string[];
  overridden: boolean;
  can_revert: boolean;
}

// eslint-disable-next-line @typescript-eslint/no-empty-object-type, @typescript-eslint/no-unsafe-declaration-merging
export default interface SiteText extends SiteTextFields {}

// eslint-disable-next-line @typescript-eslint/no-unsafe-declaration-merging
export default class SiteText extends RestModel {
  revert(
    locale: string
  ): Promise<
    Pick<
      SiteText,
      | "value"
      | "can_revert"
      | "overridden"
      | "status"
      | "old_default"
      | "new_default"
      | "interpolation_keys"
    >
  > {
    return ajax(`/admin/customize/site_texts/${this.id}?locale=${locale}`, {
      type: "DELETE",
    }).then((result: { site_text: SiteTextFields }) =>
      getProperties(
        result.site_text,
        "value",
        "can_revert",
        "overridden",
        "status",
        "old_default",
        "new_default",
        "interpolation_keys"
      )
    );
  }

  dismissOutdated(locale: string): Promise<{ success: string }> {
    return ajax(
      `/admin/customize/site_texts/${this.id}/dismiss_outdated?locale=${locale}`,
      {
        type: "PUT",
      }
    );
  }
}

declare module "discourse/services/store" {
  interface ModelRegistry {
    "site-text": SiteText;
  }
}
