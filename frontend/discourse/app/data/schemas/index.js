import { ArchetypeSchema } from "./archetype.js";
import { BadgeSchema } from "./badge.js";
import { BadgeGroupingSchema } from "./badge-grouping.js";
import { BadgeTypeSchema } from "./badge-type.js";
import { BookmarkSchema } from "./bookmark.js";
import { TagSchema } from "./tag.js";
import { TagGroupSchema } from "./tag-group.js";
import { TagInfoSchema } from "./tag-info.js";
import { TagNotificationSchema } from "./tag-notification.js";
import { TagSettingsSchema } from "./tag-settings.js";
import { TopicDetailsSchema } from "./topic-details.js";
import { UserBadgeSchema } from "./user-badge.js";

/** @type {import("@warp-drive/core/types/schema/fields").LegacyResourceSchema[]} */
export const schemas = [
  ArchetypeSchema,
  BadgeSchema,
  BadgeTypeSchema,
  BadgeGroupingSchema,
  BookmarkSchema,
  TagSchema,
  TagGroupSchema,
  TagInfoSchema,
  TagNotificationSchema,
  TagSettingsSchema,
  TopicDetailsSchema,
  UserBadgeSchema,
];
