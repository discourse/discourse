import { ajax } from "discourse/lib/ajax";
import { i18n } from "discourse-i18n";

/**
 * @typedef {{
 *   scope_id: string,
 *   key: string,
 *   name: string,
 *   params: string[] | null,
 *   urls: string[]
 * }} ApiKeyScopeDefinition
 */
/**
 * @typedef {{
 *   scope_id: string,
 *   key: string,
 *   name: string,
 *   params: string[]
 * } & Record<string, string | string[] | undefined>} SelectedApiKeyScope
 */

/**
 * Fetches the available scopes, with the global ones split out since they
 * back the read-only scope mode rather than the granular table.
 *
 * @returns {Promise<{
 *   globalScopes: ApiKeyScopeDefinition[],
 *   scopes: Record<string, ApiKeyScopeDefinition[]>
 * }>}
 */
export async function loadApiKeyScopes() {
  const { scopes } = await ajax("/admin/api/keys/scopes.json");
  const { global: globalScopes, ...resourceScopes } = scopes;
  return { globalScopes, scopes: resourceScopes };
}

/**
 * Builds the initial FormKit data for the granular scopes table.
 *
 * @param {Record<string, ApiKeyScopeDefinition[]>} scopes
 */
export function buildScopesFormData(scopes) {
  return Object.fromEntries(
    Object.entries(scopes).map(([resource, resourceScopes]) => [
      resource,
      resourceScopes.map((scope) => ({
        key: scope.key,
        enabled: undefined,
        urls: scope.urls,
        params: Object.fromEntries(
          (scope.params ?? []).map((param) => [param, undefined])
        ),
      })),
    ])
  );
}

/**
 * @param {Record<string, any[]>} scopesData granular scopes form data
 * @returns {SelectedApiKeyScope[]}
 */
export function selectedScopes(scopesData) {
  return Object.entries(scopesData).flatMap(([resource, resourceScopes]) =>
    resourceScopes
      .filter((scope) => scope.enabled)
      .map((scope) => ({
        scope_id: `${resource}:${scope.key}`,
        key: scope.key,
        name: scope.key,
        params: Object.keys(scope.params),
        ...scope.params,
      }))
  );
}

/**
 * The scopes to send for a scope mode; global keys send none.
 *
 * @param {string} scopeMode
 * @param {Record<string, any[]>} scopesData granular scopes form data
 * @param {ApiKeyScopeDefinition[]} globalScopes
 * @returns {Array<SelectedApiKeyScope | ApiKeyScopeDefinition> | undefined}
 */
export function scopesPayload(scopeMode, scopesData, globalScopes) {
  if (scopeMode === "granular") {
    return selectedScopes(scopesData);
  } else if (scopeMode === "read_only") {
    return globalScopes.filter((scope) => scope.key === "read");
  }
}

/**
 * FormKit validator requiring a granular key to have at least one scope.
 *
 * @param {{ scope_mode: string, scopes: Record<string, any[]> }} data
 * @param {{ addError: Function, removeError: Function }} helpers
 */
export function validateGranularScopes(data, { addError, removeError }) {
  removeError("scopes");

  if (
    data.scope_mode === "granular" &&
    selectedScopes(data.scopes).length === 0
  ) {
    addError("scopes", {
      title: i18n("admin.api.scopes.title"),
      message: i18n("admin.api.scopes.one_or_more"),
    });
  }
}
