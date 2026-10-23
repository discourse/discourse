import {
  createOne,
  deleteOne,
  readMany,
  readOne,
  updateOne,
} from "discourse/data/builders/helpers";
import {
  normalizeBadgeRecordPayload,
  normalizeBadgesPayload,
} from "discourse/data/normalize";
import type WarpRestModel from "discourse/data/warp-rest-model";
import { applyQueryParams } from "discourse/lib/url";

export function findBadges(opts: { onlyListable?: boolean } = {}) {
  const url = applyQueryParams("/badges.json", {
    only_listable: opts.onlyListable ? "true" : null,
  });
  return readMany(url, normalizeBadgesPayload);
}

export function findBadge(id: string | number) {
  return readOne(
    `/badges/${encodeURIComponent(id)}`,
    normalizeBadgeRecordPayload
  );
}

export function saveBadge(
  badge: WarpRestModel,
  data?: Record<string, unknown>
) {
  if (badge.id != null) {
    return updateOne(
      "badge",
      badge.id as string | number,
      `/admin/badges/${encodeURIComponent(badge.id as string | number)}`,
      data,
      normalizeBadgeRecordPayload
    );
  }
  return createOne(`/admin/badges`, data, normalizeBadgeRecordPayload);
}

export function deleteBadge(id: string | number) {
  return deleteOne("badge", id, `/admin/badges/${encodeURIComponent(id)}`);
}
