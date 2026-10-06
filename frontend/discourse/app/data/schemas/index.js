import { ArchetypeSchema } from "./archetype";
import { BadgeSchema } from "./badge";
import { BadgeGroupingSchema } from "./badge-grouping";
import { BadgeTypeSchema } from "./badge-type";
import { BookmarkSchema } from "./bookmark";
import { TagSchema } from "./tag";
import { TagGroupSchema } from "./tag-group";
import { TagInfoSchema } from "./tag-info";
import { TagNotificationSchema } from "./tag-notification";
import { TagSettingsSchema } from "./tag-settings";
import { TopicDetailsSchema } from "./topic-details";
import { UserBadgeSchema } from "./user-badge";

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
