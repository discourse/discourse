// @ts-check
import InplaceArgEditSession from "../lib/inplace-arg-edit-session";

/**
 * Owns the state of an in-place URL-edit session for a block-arg: which
 * `(blockKey, argName)` is being edited, plus the pre-edit snapshot used to push
 * a single undo entry on commit.
 *
 * Its session bookkeeping is entirely the shared `InplaceArgEditSession`
 * behavior — there is no anchored surface to open, so the base `start` /
 * `applyChange` / `stop` are inherited as-is. The UI lives in the anchored
 * `InplaceLinkPopover` (a FloatKit tooltip registered on each rendered link
 * element) which calls `start` on editing, `applyChange` on confirm, and `stop`
 * on cancel / unmount, and reads `blockKey` / `argName` to know which link is in
 * flight.
 */
export default class WireframeInplaceLinkService extends InplaceArgEditSession {}
