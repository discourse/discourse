import { getOwner } from "@ember/owner";

// Test accessors for the editor's peer services. Production code injects each
// service directly; tests historically reached the mutation engine and layout query
// through the editor handle, which the handle no longer re-exposes — look them up
// off the owner instead. Pass any owner-bearing object (a service instance, or
// `this` in a test).

export function engineOf(context) {
  return getOwner(context).lookup("service:wireframe-mutation-engine");
}

export function queryOf(context) {
  return getOwner(context).lookup("service:wireframe-layout-query");
}
