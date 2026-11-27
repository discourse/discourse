import { setOwner } from "@ember/owner";
import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import Category from "discourse/models/category";
import { FULL, REPLY } from "./constants.js";

const EVERYONE = 0;

/**
 * What a channel's privacy dialog changes, per kind of channel:
 *
 * - Forum: its category's group permissions.
 * - Text, made from the create modal: the permissions of the category that
 *   only exists to back it, always Reply so nobody starts topics in it. A
 *   chat channel on any other category shares that
 *   category with a forum channel, so it's only pointed at, not changed.
 * - Voice: whether the room is public, and adding groups' current members.
 */
export default class ChannelPrivacy {
  @service site;

  constructor(owner, creator) {
    setOwner(this, owner);
    this.creator = creator;
    this.voiceRooms = owner.lookup("service:live-rooms");
  }

  /**
   * @returns {object|null} The dialog's model for the channel, or null when
   *   the user can't change who sees it.
   */
  forLink(link) {
    const [type] = link.channelKey.split(":");

    switch (type) {
      case "forum":
        return link.category.can_edit ? this.#category(link.category) : null;
      case "text":
        return this.#text(link.channel);
      case "voice":
        return link.room.can_manage ? this.#voice(link.room) : null;
      default:
        return null;
    }
  }

  #text(channel) {
    const category = Category.findById(channel.chatableId);

    if (!category?.can_edit) {
      return null;
    }

    if (category.parentCategory?.slug !== settings.chat_container_category) {
      return { kind: "shared", category };
    }

    return this.#category(
      category,
      (isPrivate) => {
        if (channel.chatable) {
          channel.chatable.read_restricted = isPrivate;
        }
      },
      REPLY
    );
  }

  // Core requires every group that can see a subcategory to be able to see
  // its parent, so a parent keeps its subcategories' groups (and can't be
  // private while one is public), and a subcategory can only use groups its
  // parent allows.
  //
  // With a fixed level, every group (or everyone, when public) gets that
  // level, whatever it had before.
  #category(category, afterSave, fixedLevel = null) {
    return {
      kind: "category",
      requiresGroups: true,

      load: async () => {
        const [own, subcategories, parent] = await Promise.all([
          this.#permissionsOf(category),
          Promise.all(
            this.site.categories
              .filter((c) => c.parent_category_id === category.id)
              .map(async (c) => ({
                category: c,
                permissions: await this.#permissionsOf(c),
              }))
          ),
          category.parentCategory
            ? this.#permissionsOf(category.parentCategory)
            : null,
        ]);

        const required = new Map();
        let publicSubcategory = null;

        for (const sub of subcategories) {
          for (const permission of sub.permissions) {
            if (permission.group_id === EVERYONE) {
              publicSubcategory ||= sub.category.displayName;
            } else {
              required.set(permission.group_id, permission.group_name);
            }
          }
        }

        const parentIsPrivate =
          parent && !parent.some((p) => p.group_id === EVERYONE);
        const isPrivate = !own.some((p) => p.group_id === EVERYONE);

        return {
          isPrivate,
          groupIds: isPrivate
            ? own.map((p) => p.group_id).filter((id) => !required.has(id))
            : [],
          existing: own,
          required: [...required].map(([id, name]) => ({ id, name })),
          publicSubcategory,
          allowedGroupIds: parentIsPrivate
            ? new Set(parent.map((p) => p.group_id))
            : null,
          privateParent: parentIsPrivate
            ? {
                name: category.parentCategory.displayName,
                securityUrl: `/c/${Category.slugFor(category.parentCategory)}/edit/security`,
                groupNames: parent.map((p) => p.group_name),
              }
            : null,
        };
      },

      // Groups that stay keep the level they had (core's category settings
      // can give a group less than full access); groups added get full access.
      // Going public opens it to everyone in full.
      save: async ({ isPrivate, groupIds }, { existing, required }) => {
        const permissions = {};

        if (isPrivate) {
          const ids = new Set([...groupIds, ...required.map((g) => g.id)]);

          for (const id of ids) {
            const kept = existing.find((p) => p.group_id === id);
            const name =
              kept?.group_name ||
              required.find((g) => g.id === id)?.name ||
              this.site.groups.find((group) => group.id === id)?.name;

            if (name) {
              permissions[name] = fixedLevel || kept?.permission_type || FULL;
            }
          }
        } else if (
          !fixedLevel &&
          existing.some((p) => p.group_id === EVERYONE)
        ) {
          // Already public: left as it is, since everyone may have less than
          // full access (see only, say) with staff groups set apart.
          for (const p of existing) {
            permissions[p.group_name] = p.permission_type;
          }
        } else {
          permissions.everyone = fixedLevel || FULL;
        }

        const result = await ajax(`/categories/${category.id}`, {
          type: "PUT",
          data: { permissions },
        });

        this.site.updateCategory(result.category || result);
        afterSave?.(isPrivate);
      },
    };
  }

  async #permissionsOf(category) {
    const result = await ajax(`/c/${category.id}/show.json`);
    return result.category.group_permissions;
  }

  #voice(room) {
    return {
      kind: "voice",
      requiresGroups: false,

      load: async () => ({ isPrivate: !room.public, groupIds: [] }),

      save: async ({ isPrivate, groupIds }) => {
        const result = await ajax(`/live/rooms/${room.id}`, {
          type: "PUT",
          data: { room: { public: !isPrivate } },
        });

        this.voiceRooms.upsertRoom(result.room);

        if (isPrivate && groupIds.length) {
          return this.creator.addGroupMembersToRoom(room, groupIds);
        }
      },
    };
  }
}
