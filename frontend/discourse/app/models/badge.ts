import {
  deleteBadge,
  findBadge,
  findBadges,
  saveBadge,
} from "discourse/data/builders/badges";
import { normalizeBadgesPayload } from "discourse/data/normalize";
import RestCompatModel from "discourse/data/rest-compat";
import { BadgeSchema } from "discourse/data/schemas/badge";
import { defineFieldForwarders } from "discourse/data/warp-rest-model";
import getURL from "discourse/lib/get-url";

/** Cached BadgeTypeSerializer data; relationship records retain string ids. */
export interface CachedBadgeTypeRecord {
  id: string;
  name: string;
  sort_order: number;
}

/** Cached BadgeGroupingSerializer data; relationship records retain string ids. */
export interface CachedBadgeGroupingRecord {
  id: string;
  name: string;
  description: string | null;
  position: number;
  system: boolean;
  /** The translated name, added during normalization. */
  displayName?: string;
}

/**
 * BadgeSerializer, BadgeIndexSerializer and AdminBadgeSerializer fields.
 * Fields beyond id and name may be absent from partial responses or unsaved admin drafts.
 */
export interface BadgeFields {
  id: number;
  name: string;
  /** The model supplies an empty string when no description is stored. */
  description?: string;
  /** Sent on request, and always to admins. */
  long_description?: string;
  slug?: string;
  icon?: string | null;
  image_url?: string | null;
  grant_count?: number;
  enabled?: boolean;
  /** The column is nullable despite its default. */
  listable?: boolean | null;
  show_in_post_header?: boolean;
  /** Sent only with the viewer's grants; badge normalization defaults it to false. */
  has_badge?: boolean;
  allow_title?: boolean;
  multiple_grant?: boolean;
  manually_grantable?: boolean;
  system?: boolean;
  badge_type_id?: number;
  badge_grouping_id?: number;
  /** AdminBadgeSerializer only. */
  query?: string | null;
  trigger?: number | null;
  target_posts?: boolean | null;
  auto_revoke?: boolean;
  show_posts?: boolean;
  /** Admin serializer, system badges only. */
  i18n_name?: string;
  /** Admin serializer only; null without an uploaded image. */
  image_upload_id?: number | null;
  /** Relationship forwarders have no setter; null when the payload did not sideload the record. */
  readonly badge_type?: CachedBadgeTypeRecord | null;
  readonly badge_grouping?: CachedBadgeGroupingRecord | null;
}

/** A BadgeSerializer row as the server sends it. */
export interface BadgePayload
  extends
    Required<
      Pick<
        BadgeFields,
        | "id"
        | "name"
        | "description"
        | "grant_count"
        | "allow_title"
        | "multiple_grant"
        | "icon"
        | "image_url"
        | "listable"
        | "enabled"
        | "badge_grouping_id"
        | "system"
        | "slug"
        | "manually_grantable"
        | "show_in_post_header"
        | "badge_type_id"
      >
    >,
    Pick<BadgeFields, "long_description" | "has_badge"> {}

/** Schema forwarders expose these fields without adding instance properties. */
// eslint-disable-next-line @typescript-eslint/no-empty-object-type, @typescript-eslint/no-unsafe-declaration-merging
export default interface Badge extends BadgeFields {}

// eslint-disable-next-line @typescript-eslint/no-unsafe-declaration-merging
export default class Badge extends RestCompatModel {
  static override type = "badge";

  /** Type-only opt-in: the normalizer treats this root as a single record. */
  declare static singleRecordRoot: "badge";
  static override normalize = normalizeBadgesPayload;
  static override builders = {
    list: findBadges,
    one: findBadge,
    save: saveBadge,
    delete: deleteBadge,
  };

  declare id: number;

  /** Client-only: the user summary copies the grant count onto its badges. */
  declare count?: number;

  // The `icon-or-image` helper reads `badge.image`.
  get image(): string | null | undefined {
    return this.image_url;
  }

  get url(): string {
    return getURL(`/badges/${this.id}/${this.slug}`);
  }

  get newBadge() {
    return this.id == null;
  }

  get badgeTypeClassName() {
    const type = this.badge_type?.name || "";
    return `badge-type-${type.toLowerCase()}`;
  }
}

defineFieldForwarders(Badge, BadgeSchema);
