// Registry for the admin components that configure MCP content rule kinds.
// Core and plugins register a component for an admin component id via
// `api.registerMcpContentRuleComponent`; the id must match the
// `admin_component_id` the rule kind was registered with server-side. Core
// rule kinds ship their own components, which registrations can't replace.

import AdminMcpForumContentRule from "discourse/admin/components/admin-mcp-forum-content-rule";
import AdminMcpPrivateMessagesRule from "discourse/admin/components/admin-mcp-private-messages-rule";

const CORE_COMPONENTS = new Map([
  ["forum_content", AdminMcpForumContentRule],
  ["private_messages", AdminMcpPrivateMessagesRule],
]);

const components = new Map();

/**
 * Registers the component that configures a content rule kind.
 *
 * @param {string} id - The rule kind's admin component id.
 * @param {Component} ComponentClass - A Glimmer component for the rule kind.
 */
export function registerMcpContentRuleComponent(id, ComponentClass) {
  components.set(id, ComponentClass);
}

/**
 * @param {string} id - The rule kind's admin component id.
 * @returns {Component|undefined} The registered component, if any.
 */
export function lookupMcpContentRuleComponent(id) {
  return CORE_COMPONENTS.get(id) ?? components.get(id);
}

export function resetMcpContentRuleComponents() {
  components.clear();
}
