import { service } from "@ember/service";
import { BlockCondition, raiseBlockValidationError } from "./base";

/**
 * A condition that evaluates based on user state.
 *
 * Supports checking login status, trust level, admin/moderator status, and group membership.
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
 */
export default class BlockUserCondition extends BlockCondition {
  static type = "user";

  @service currentUser;

  validate(args) {
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

  evaluate(args) {
    const {
      loggedIn,
      admin,
      moderator,
      staff,
      minTrustLevel,
      maxTrustLevel,
      groups,
    } = args;

    // Check login state
    if (loggedIn === true && !this.currentUser) {
      return false;
    }
    if (loggedIn === false && this.currentUser) {
      return false;
    }

    // All other checks require a logged-in user
    if (!this.currentUser) {
      // If loggedIn: false was specified, anonymous users pass
      if (loggedIn === false) {
        return true;
      }

      // If user-specific conditions are specified, anonymous users cannot satisfy them
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

      // No user-specific conditions, pass for anonymous if loggedIn wasn't explicitly required
      return loggedIn === undefined;
    }

    // Check admin status
    if (admin === true && !this.currentUser.admin) {
      return false;
    }

    // Check moderator status (admins are also moderators)
    if (
      moderator === true &&
      !this.currentUser.moderator &&
      !this.currentUser.admin
    ) {
      return false;
    }

    // Check staff status
    if (staff === true && !this.currentUser.staff) {
      return false;
    }

    // Check trust level range
    if (
      minTrustLevel !== undefined &&
      this.currentUser.trust_level < minTrustLevel
    ) {
      return false;
    }
    if (
      maxTrustLevel !== undefined &&
      this.currentUser.trust_level > maxTrustLevel
    ) {
      return false;
    }

    // Check group membership
    if (groups?.length && !this.#isInAnyGroup(groups)) {
      return false;
    }

    return true;
  }

  /**
   * Checks if the current user is a member of at least one of the specified groups.
   * This implements OR logic for group membership: if the user belongs to any of
   * the provided groups, the check passes.
   *
   * @param {Array<string>} groupNames - Array of group names to check membership against.
   * @returns {boolean} True if the user is in at least one of the specified groups.
   */
  #isInAnyGroup(groupNames) {
    // Extract the names of all groups the current user belongs to
    const userGroups = this.currentUser.groups?.map((g) => g.name) || [];
    // Check if any of the required group names appear in the user's groups
    return groupNames.some((name) => userGroups.includes(name));
  }
}
