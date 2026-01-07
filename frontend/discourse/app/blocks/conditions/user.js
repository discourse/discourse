import { service } from "@ember/service";
import { BlockCondition, raiseBlockValidationError } from "./condition";
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
 * | `loggedIn`      | `boolean`  | If true, passes only for logged-in users; if false, only for anon     |
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
    super.validate(args);

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
        raiseBlockValidationError(
          "BlockUserCondition: Cannot use `loggedIn: false` with user-specific conditions " +
            "(admin, moderator, staff, minTrustLevel, maxTrustLevel, groups). " +
            "Anonymous users cannot have these properties."
        );
      }
    }

    // Validate trust level values are numbers in valid range (0-4)
    if (minTrustLevel !== undefined) {
      if (
        typeof minTrustLevel !== "number" ||
        minTrustLevel < 0 ||
        minTrustLevel > 4
      ) {
        raiseBlockValidationError(
          "BlockUserCondition: `minTrustLevel` must be a number between 0 and 4."
        );
      }
    }
    if (maxTrustLevel !== undefined) {
      if (
        typeof maxTrustLevel !== "number" ||
        maxTrustLevel < 0 ||
        maxTrustLevel > 4
      ) {
        raiseBlockValidationError(
          "BlockUserCondition: `maxTrustLevel` must be a number between 0 and 4."
        );
      }
    }

    // Check for minTrustLevel > maxTrustLevel
    if (
      minTrustLevel !== undefined &&
      maxTrustLevel !== undefined &&
      minTrustLevel > maxTrustLevel
    ) {
      raiseBlockValidationError(
        `BlockUserCondition: \`minTrustLevel\` (${minTrustLevel}) cannot be greater than ` +
          `\`maxTrustLevel\` (${maxTrustLevel}). No user can satisfy this condition.`
      );
    }
  }

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

    // Check login state (only meaningful for currentUser, not source users)
    if (loggedIn === true && !user) {
      return false;
    }
    if (loggedIn === false && user) {
      return false;
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
