// @ts-check
import { service } from "@ember/service";
import { BlockCondition } from "./condition";
import { blockCondition } from "./decorator";

/**
 * A condition that evaluates based on user state.
 *
 * Supports checking login status, trust level, admin/moderator status, and group membership.
 * By default, checks the current logged-in user. Use `source` to check a different user
 * object from outlet args.
 *
 * **Important: Multiple conditions use AND logic.** All specified conditions must be satisfied
 * for the condition to pass. For example, `{ minTrustLevel: 2, groups: ["beta-testers"] }` requires
 * the user to have trust level 2+ AND be a member of the beta-testers group.
 *
 * The only exception is the `groups` array itself, which uses OR logic internally
 * (user must be in at least ONE of the specified groups).
 *
 * @class BlockUserCondition
 * @extends BlockCondition
 *
 * ## Condition Configuration Properties
 *
 * These properties are passed as an args object to `validate()` and `evaluate()`:
 *
 * | Property        | Type       | Description                                                           |
 * |-----------------|------------|-----------------------------------------------------------------------|
 * | `source`        | `string`   | Optional. Path to user object in outlet args (e.g., `@outletArgs.user`)|
 * | `loggedIn`      | `boolean`  | If true, passes for logged-in users (or if source matches currentUser)|
 * | `admin`         | `boolean`  | If true, passes only for admin users                                  |
 * | `moderator`     | `boolean`  | If true, passes only for moderators (includes admins)                 |
 * | `staff`         | `boolean`  | If true, passes only for staff members                                |
 * | `minTrustLevel` | `number`   | Minimum trust level required (0-4)                                    |
 * | `maxTrustLevel` | `number`   | Maximum trust level allowed (0-4)                                     |
 * | `groups`        | `string[]` | User must be in at least one of these groups (OR logic)               |
 *
 * @example
 * // Logged-in users only
 * { type: "user", loggedIn: true }
 *
 * @example
 * // Anonymous users only
 * { type: "user", loggedIn: false }
 *
 * @example
 * // Admin users only
 * { type: "user", admin: true }
 *
 * @example
 * // Trust level 2+ AND in specific groups
 * { type: "user", minTrustLevel: 2, groups: ["beta-testers", "power-users"] }
 *
 * @example
 * // Check a user from outlet args instead of currentUser
 * { type: "user", source: "@outletArgs.topicAuthor", admin: true }
 *
 * @example
 * // Check if source user IS the current logged-in user
 * { type: "user", source: "@outletArgs.post.user", loggedIn: true }
 *
 * @example
 * // Check if source user is NOT the current user (e.g., for "follow" button)
 * { type: "user", source: "@outletArgs.user", loggedIn: false }
 */
@blockCondition({
  type: "user",
  sourceType: "outletArgs",
  validArgKeys: [
    "loggedIn",
    "admin",
    "moderator",
    "staff",
    "minTrustLevel",
    "maxTrustLevel",
    "groups",
  ],
})
export default class BlockUserCondition extends BlockCondition {
  @service currentUser;

  validate(args) {
    // Check base class validation (source parameter)
    const baseError = super.validate(args);
    if (baseError) {
      return baseError;
    }

    const {
      loggedIn,
      admin,
      moderator,
      staff,
      minTrustLevel,
      maxTrustLevel,
      groups,
    } = args;

    // Check for loggedIn: false with user-specific conditions
    if (loggedIn === false) {
      const hasUserConditions =
        admin !== undefined ||
        moderator !== undefined ||
        staff !== undefined ||
        minTrustLevel !== undefined ||
        maxTrustLevel !== undefined ||
        groups?.length;

      if (hasUserConditions) {
        return {
          message:
            "Cannot use `loggedIn: false` with user-specific conditions " +
            "(admin, moderator, staff, minTrustLevel, maxTrustLevel, groups). " +
            "Anonymous users cannot have these properties.",
        };
      }
    }

    // Validate trust level values are numbers in valid range (0-4)
    if (minTrustLevel !== undefined) {
      if (
        typeof minTrustLevel !== "number" ||
        minTrustLevel < 0 ||
        minTrustLevel > 4
      ) {
        return {
          message: "`minTrustLevel` must be a number between 0 and 4.",
          path: "minTrustLevel",
        };
      }
    }
    if (maxTrustLevel !== undefined) {
      if (
        typeof maxTrustLevel !== "number" ||
        maxTrustLevel < 0 ||
        maxTrustLevel > 4
      ) {
        return {
          message: "`maxTrustLevel` must be a number between 0 and 4.",
          path: "maxTrustLevel",
        };
      }
    }

    // Check for minTrustLevel > maxTrustLevel
    if (
      minTrustLevel !== undefined &&
      maxTrustLevel !== undefined &&
      minTrustLevel > maxTrustLevel
    ) {
      return {
        message:
          `\`minTrustLevel\` (${minTrustLevel}) cannot be greater than ` +
          `\`maxTrustLevel\` (${maxTrustLevel}). No user can satisfy this condition.`,
      };
    }

    return null;
  }

  /**
   * Evaluates whether the user condition passes.
   *
   * @param {Object} args - The condition arguments.
   * @param {Object} [context] - Evaluation context.
   * @param {Object} [context.outletArgs] - Outlet args for source resolution.
   * @returns {boolean} True if the condition passes.
   */
  evaluate(args, context) {
    const {
      loggedIn,
      admin,
      moderator,
      staff,
      minTrustLevel,
      maxTrustLevel,
      groups,
    } = args;

    // Get user from source (outlet args) if provided, otherwise use currentUser.
    // Important: If source is provided but resolves to undefined, we use undefined (don't fall back)
    const user =
      args.source !== undefined
        ? this.resolveSource(args, context)
        : this.currentUser;

    // Check login state or current user match (when source is provided)
    if (loggedIn !== undefined) {
      if (args.source !== undefined) {
        // When source is provided, check if source user IS the current user
        const isCurrentUser = this.#isSameUser(user, this.currentUser);
        if (loggedIn === true && !isCurrentUser) {
          return false;
        }
        if (loggedIn === false && isCurrentUser) {
          return false;
        }
      } else {
        // Check if there is a logged-in user
        if (loggedIn === true && !user) {
          return false;
        }
        if (loggedIn === false && user) {
          return false;
        }
      }
    }

    // All other checks require a user
    if (!user) {
      // If loggedIn: false was specified, no user passes
      if (loggedIn === false) {
        return true;
      }

      // If user-specific conditions are specified, no user cannot satisfy them
      const hasUserSpecificConditions =
        admin !== undefined ||
        moderator !== undefined ||
        staff !== undefined ||
        minTrustLevel !== undefined ||
        maxTrustLevel !== undefined ||
        groups?.length;

      if (hasUserSpecificConditions) {
        return false;
      }

      // No user-specific conditions, pass if loggedIn wasn't explicitly required
      return loggedIn === undefined;
    }

    // Check admin status
    if (admin === true && !user.admin) {
      return false;
    }

    // Check moderator status (admins are also moderators)
    if (moderator === true && !user.moderator && !user.admin) {
      return false;
    }

    // Check staff status
    if (staff === true && !user.staff) {
      return false;
    }

    // Check trust level range
    if (minTrustLevel !== undefined && user.trust_level < minTrustLevel) {
      return false;
    }
    if (maxTrustLevel !== undefined && user.trust_level > maxTrustLevel) {
      return false;
    }

    // Check group membership
    if (groups?.length && !this.#isInAnyGroup(user, groups)) {
      return false;
    }

    return true;
  }

  /**
   * Checks if two user objects represent the same user by comparing their ids.
   * Used when `source` is provided with `loggedIn` to check if the source user
   * is the current logged-in user.
   *
   * @param {Object} user1 - First user object.
   * @param {Object} user2 - Second user object.
   * @returns {boolean} True if both users exist and have the same id.
   */
  #isSameUser(user1, user2) {
    if (!user1 || !user2) {
      return false;
    }
    if (user1.id != null && user2.id != null) {
      return user1.id === user2.id;
    }
    return user1 === user2;
  }

  /**
   * Checks if a user is a member of at least one of the specified groups.
   * This implements OR logic for group membership: if the user belongs to any of
   * the provided groups, the check passes.
   *
   * @param {Object} user - The user object to check.
   * @param {Array<string>} groupNames - Array of group names to check membership against.
   * @returns {boolean} True if the user is in at least one of the specified groups.
   */
  #isInAnyGroup(user, groupNames) {
    // Extract the names of all groups the user belongs to
    const userGroups = user.groups?.map((g) => g.name) || [];
    // Check if any of the required group names appear in the user's groups
    return groupNames.some((name) => userGroups.includes(name));
  }
}
