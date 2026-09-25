import { getOwner } from "@ember/owner";

/**
 * Opens the invite creation modal, selecting the redesigned role-based
 * variant when the `enable_invite_modal_with_roles` upcoming change is enabled.
 *
 * @param {Object} context - any owned object (component, route, controller)
 * @param {Object} opts - options forwarded to `modal.show`, e.g. `{ model }`
 * @returns {Promise} the modal promise from `modal.show`
 */
export function showCreateInviteModal(context, opts = {}) {
  const owner = getOwner(context);
  const modal = owner.lookup("service:modal");
  const siteSettings = owner.lookup("service:site-settings");

  const component = siteSettings.enable_invite_modal_with_roles
    ? () => import("discourse/components/modal/create-invite-with-roles")
    : () => import("discourse/components/modal/create-invite");

  return modal.show(component, opts);
}
