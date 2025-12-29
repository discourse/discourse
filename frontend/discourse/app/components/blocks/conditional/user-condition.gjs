import Component from "@glimmer/component";
import { service } from "@ember/service";
import { block } from "discourse/components/block-outlet";

/**
 * A conditional container block that renders children based on user state.
 * Supports checking login status, trust level, admin/moderator status, and group membership.
 *
 * **Important: Multiple conditions use AND logic.** All specified conditions must be satisfied
 * for the block to render. For example, `{ minTrustLevel: 2, groups: ["beta-testers"] }` requires
 * the user to have trust level 2+ AND be a member of the beta-testers group.
 *
 * The only exception is the `groups` array itself, which uses OR logic internally
 * (user must be in at least ONE of the specified groups).
 *
 * @component UserCondition
 * @param {boolean} [loggedIn] - If true, render only for logged-in users; if false, only for anonymous
 * @param {boolean} [admin] - If true, render only for admin users
 * @param {boolean} [moderator] - If true, render only for moderators (includes admins)
 * @param {boolean} [staff] - If true, render only for staff members
 * @param {number} [minTrustLevel] - Minimum trust level required (0-4)
 * @param {number} [maxTrustLevel] - Maximum trust level allowed (0-4)
 * @param {Array<string>} [groups] - User must be member of at least ONE of these groups (OR logic)
 *
 * @example
 * // Render only for logged-in users
 * {
 *   block: UserCondition,
 *   args: { loggedIn: true },
 *   children: [
 *     { block: BlockUserDashboard }
 *   ]
 * }
 *
 * @example
 * // Render only for staff members
 * {
 *   block: UserCondition,
 *   args: { staff: true },
 *   children: [
 *     { block: BlockAdminPanel }
 *   ]
 * }
 *
 * @example
 * // Render for trust level 2+ users who are also in specific groups (AND logic)
 * // User must have TL2+ AND be in beta-testers OR power-users group
 * {
 *   block: UserCondition,
 *   args: { minTrustLevel: 2, groups: ["beta-testers", "power-users"] },
 *   children: [
 *     { block: BlockBetaFeatures }
 *   ]
 * }
 */
@block("user-condition", { container: true })
export default class UserCondition extends Component {
  @service currentUser;

  get shouldRender() {
    const {
      loggedIn,
      admin,
      moderator,
      staff,
      minTrustLevel,
      maxTrustLevel,
      groups,
    } = this.args;

    // Check login state
    if (loggedIn === true && !this.currentUser) {
      return false;
    }
    if (loggedIn === false && this.currentUser) {
      return false;
    }

    // All other checks require a logged-in user
    if (!this.currentUser) {
      return loggedIn === undefined; // No conditions specified, render for anonymous
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

  #isInAnyGroup(groupNames) {
    const userGroups = this.currentUser.groups?.map((g) => g.name) || [];
    return groupNames.some((name) => userGroups.includes(name));
  }

  <template>
    {{#if this.shouldRender}}
      {{#each this.children as |child|}}
        <child.Component @outletName={{@outletName}} />
      {{/each}}
    {{/if}}
  </template>
}
