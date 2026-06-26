// @ts-check

/**
 * @typedef {{ allowedOutlets?: string[], deniedOutlets?: string[] }} BlockMetadata
 *   The outlet-restriction slice of a block's metadata. `allowedOutlets`, when
 *   non-empty, is a strict allow-list; `deniedOutlets` is a block-list.
 */

/**
 * Decides whether a drag/insert is allowed into a target outlet — the
 * per-dragover authorization the drop targets consult.
 *
 * A pure-read, dependency-free leaf: the kernel constructs it with the
 * drag-session leaf plus down-injected lookup functions, so it holds opaque
 * capabilities and never reaches back into any service. Only query methods (no
 * mutators), so the kernel may expose the instance directly.
 */
export default class DropAuthority {
  #session;
  #findEntryByKey;
  #metadataFor;
  #metadataForName;

  /**
   * @param {{
   *   session: import("./drag-session-state").default,
   *   findEntryByKey: (key: string) => Object|null,
   *   metadataFor: (entry: Object) => BlockMetadata|null,
   *   metadataForName: (blockName: string) => BlockMetadata|null,
   * }} deps
   */
  constructor({ session, findEntryByKey, metadataFor, metadataForName }) {
    this.#session = session;
    this.#findEntryByKey = findEntryByKey;
    this.#metadataFor = metadataFor;
    this.#metadataForName = metadataForName;
  }

  /**
   * Whether dropping the currently-dragged block into `targetOutletName` is
   * allowed. Same-outlet moves (and an idle session) always pass; cross-outlet
   * moves consult the source block's outlet restrictions.
   *
   * @param {{targetOutletName: string}} target
   * @returns {boolean}
   */
  canDropAt({ targetOutletName }) {
    const sourceKey = this.#session.sourceKey;
    if (!sourceKey) {
      return true;
    }
    if (!targetOutletName || targetOutletName === this.#session.sourceOutlet) {
      return true;
    }
    const sourceEntry = this.#findEntryByKey(sourceKey);
    if (!sourceEntry) {
      return false;
    }
    return this.#outletAllowed(
      this.#metadataFor(sourceEntry),
      targetOutletName
    );
  }

  /**
   * Whether inserting a fresh `blockName` block into `targetOutletName` is
   * allowed by the block class's outlet restrictions. The insert path, with no
   * in-flight drag source to consult.
   *
   * @param {{blockName: string, targetOutletName: string}} target
   * @returns {boolean}
   */
  canInsertBlockAt({ blockName, targetOutletName }) {
    if (!blockName || !targetOutletName) {
      return false;
    }
    return this.#outletAllowed(
      this.#metadataForName(blockName),
      targetOutletName
    );
  }

  /**
   * Shared allow/deny check. Permissive when metadata is missing (an
   * unregistered block — the server-side validator catches a truly broken one
   * on save); `deniedOutlets` blocks; a non-empty `allowedOutlets` is a strict
   * allow-list.
   *
   * @param {BlockMetadata|null} metadata
   * @param {string} targetOutletName
   * @returns {boolean}
   */
  #outletAllowed(metadata, targetOutletName) {
    if (!metadata) {
      return true;
    }
    if (metadata.deniedOutlets?.includes(targetOutletName)) {
      return false;
    }
    if (metadata.allowedOutlets?.length > 0) {
      return metadata.allowedOutlets.includes(targetOutletName);
    }
    return true;
  }
}
