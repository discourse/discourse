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

export default class Badge extends RestCompatModel {
  static type = "badge";
  static normalize = normalizeBadgesPayload;
  static builders = {
    list: findBadges,
    one: findBadge,
    save: saveBadge,
    delete: deleteBadge,
  };

  // The `icon-or-image` helper reads `badge.image`.
  get image() {
    return this.image_url;
  }

  get url() {
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
