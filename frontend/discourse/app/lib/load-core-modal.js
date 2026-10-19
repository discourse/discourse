import { waitForPromise } from "@ember/test-waiters";

export const CORE_MODAL_PREFIX = "discourse/components/modal/";

const modules = import.meta.glob("../components/modal/**/*.{js,gjs}");

/**
 * @param {string} moduleName Full import path, e.g. `discourse/components/modal/flag`.
 * @param {boolean} [optional=false] Resolve with an empty module when the path is unknown.
 * @returns {Promise<object>} The module's exports.
 */
export default async function loadCoreModal(moduleName, optional = false) {
  const path = `../components/modal/${moduleName.slice(CORE_MODAL_PREFIX.length)}`;
  const load = modules[`${path}.gjs`] ?? modules[`${path}.js`];

  if (!load) {
    if (optional) {
      return {};
    }
    throw new Error(`Unknown core modal: ${moduleName}`);
  }

  return waitForPromise(load());
}
