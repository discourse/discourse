import RestCompatModel from "discourse/data/rest-compat";
import { TagSchema } from "discourse/data/schemas/tag";
import { defineFieldForwarders } from "discourse/data/warp-rest-model";
import getURL from "discourse/lib/get-url";
import type { RestModelStoreAttrs } from "discourse/models/rest";

/** A plain tag reference, rather than a model instance. */
export interface TagReference {
  id: number;
  name: string;
  slug: string;
}

/** TagLocalizationSerializer fields embedded in tag responses. */
export interface TagLocalization {
  id: number;
  tag_id: number;
  locale: string;
  name: string;
  description: string | null;
  description_cooked: string | null;
}

/** A tag count row before the client wraps it in a Tag. */
export interface TagCountRow extends TagReference {
  text: string;
  description: string | null;
  count: number;
  pm_only: boolean;
  /** Null unless the tag is a synonym whose target the viewer can see. */
  target_tag: TagReference | null;
  /** Sent only when the viewer can tag personal messages and PM tag counts are shown. */
  pm_count?: number;
}

/**
 * Fields across tag count rows, top tags and TagSerializer rows. Only `name` is
 * always present: the tag page builds a placeholder from the URL before loading.
 */
export interface TagFields {
  /** Absent on tags built from a name; null on the tag page when the URL has no tag id. */
  id?: number | null;
  name: string;
  slug?: string;
  description?: string | null;
  /** TagSerializer rows only. */
  description_cooked?: string | null;
  /** Count rows repeat the name here. */
  text?: string;
  /** Count rows only: the topic count the viewer can see. */
  count?: number;
  /** Sent only when the viewer can tag personal messages and PM tag counts are shown. */
  pm_count?: number;
  pm_only?: boolean;
  /** TagSerializer rows only. */
  topic_count?: number;
  staff?: boolean;
  /** Null unless the tag is a synonym whose target the viewer can see. */
  target_tag?: TagReference | null;
  /** Sent only when localization is enabled and the association is preloaded. */
  localizations?: TagLocalization[];
}

/** Store creation takes tag rows, whose named interfaces have no index signature. */
export type TagCreateAttrs = Partial<Tag> & RestModelStoreAttrs;

/** Schema forwarders expose these fields without adding instance properties. */
// eslint-disable-next-line @typescript-eslint/no-empty-object-type, @typescript-eslint/no-unsafe-declaration-merging
export default interface Tag extends TagFields {}

// eslint-disable-next-line @typescript-eslint/no-unsafe-declaration-merging
export default class Tag extends RestCompatModel {
  static override type = "tag";

  declare id?: number | null;

  get pmOnly(): boolean | undefined {
    return this.pm_only;
  }

  get url(): string {
    if (this.id) {
      const slugForUrl = this.slug || `${this.id}-tag`;
      return getURL(`/tag/${slugForUrl}/${this.id}`);
    }
    // fallback for tags without id (legacy)
    return getURL(`/tag/${this.name.replaceAll(".", "%2E")}`);
  }

  get totalCount(): number | undefined {
    return this.pm_count ? this.count! + this.pm_count : this.count;
  }

  get searchContext(): {
    type: "tag";
    id: number | null | undefined;
    tag: Tag;
    name: string;
  } {
    return {
      type: "tag",
      id: this.id,
      tag: this,
      name: this.name,
    };
  }
}

defineFieldForwarders(Tag, TagSchema);
