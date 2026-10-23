import type { LegacyResourceSchema } from "@warp-drive/core/types/schema/fields";
import { ArchetypeSchema } from "./archetype.ts";
import { BadgeSchema } from "./badge.ts";
import { BadgeGroupingSchema } from "./badge-grouping.ts";
import { BadgeTypeSchema } from "./badge-type.ts";
import { BookmarkSchema } from "./bookmark.ts";
import { GroupsSchema } from "./json-api/groups.ts";
import { UsersSchema } from "./json-api/users.ts";
import { TagSchema } from "./tag.ts";
import { TagGroupSchema } from "./tag-group.ts";
import { TagInfoSchema } from "./tag-info.ts";
import { TagNotificationSchema } from "./tag-notification.ts";
import { TagSettingsSchema } from "./tag-settings.ts";
import { TopicDetailsSchema } from "./topic-details.ts";
import { UserBadgeSchema } from "./user-badge.ts";

export const schemas: LegacyResourceSchema[] = [
  ArchetypeSchema,
  BadgeSchema,
  BadgeTypeSchema,
  BadgeGroupingSchema,
  BookmarkSchema,
  GroupsSchema,
  TagSchema,
  TagGroupSchema,
  TagInfoSchema,
  TagNotificationSchema,
  TagSettingsSchema,
  TopicDetailsSchema,
  UserBadgeSchema,
  UsersSchema,
];
