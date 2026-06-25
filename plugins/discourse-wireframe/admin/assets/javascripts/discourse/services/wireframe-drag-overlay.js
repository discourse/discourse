// @ts-check
import { trackedObject } from "@ember/reactive/collections";
import Service, { service } from "@ember/service";

/**
 * @typedef {{ action: string, args: Object }} DropDispatch
 *   A layout mutation to run at drop time, executed by
 *   `wireframe.runDropDispatch`.
 *
 * @typedef {{ top: number, left: number, width: number, height: number }} OverlayGeometry
 *   Viewport-relative pixel rect for the slot-insert indicator.
 *
 * @typedef {Object} SlotDropDescriptor
 *   The raw descriptor produced by the container / grid resolvers and handed to
 *   `claimSlotInsert`.
 * @property {OverlayGeometry} geometry
 * @property {string} kind - insert / inside / replace / swap / shift / occupy.
 * @property {"valid"|"invalid"} validity
 * @property {?string} label
 * @property {?DropDispatch} dispatch - `null` when the drop is invalid.
 *
 * @typedef {Object} ImageArgClaim
 *   Identity of an image arg whose overlay is claiming the slot.
 * @property {string} blockKey
 * @property {string} argName
 * @property {boolean} isPassive - A full-bleed background marker vs a foreground slot.
 * @property {"light"|"dark"} [variant] - Which variant a drop targets (default light).
 *
 * @typedef {(
 *   { kind: "slot-insert", seq: number, geometry: OverlayGeometry, previewKind: string, validity: ("valid"|"invalid"), label: ?string, dispatch: ?DropDispatch } |
 *   { kind: "image-arg", seq: number, blockKey: string, argName: string, isPassive: boolean, variant: ("light"|"dark") } |
 *   { kind: null, seq: number }
 * )} ActiveDragOverlay
 *   The single active overlay. `kind` is the discriminator; `kind: null` is an
 *   own-but-blank claim (the deepest target owns the slot but shows nothing).
 *
 * @typedef {{ previewKind: string, validity: ("valid"|"invalid"), label: ?string, geometry: OverlayGeometry }} SlotPreview
 *   The frozen, read-only projection of the active slot-insert that `slotPreview`
 *   hands to consumers. A copy, never the live internal object, so consumers
 *   cannot mutate the coordinator's state.
 */

/**
 * Single chokepoint for the editor's drag-time overlays.
 *
 * During a drag, several overlays compete to show: the slot-insert indicator
 * (`DropPreview`), a filled image's "will be overwritten" tint, the passive
 * background-fill tint, and the dark-variant popover. Left to their own state
 * they can paint at once and disagree about where a release will land — the
 * drop targets fire enter/drag only on the DEEPEST target, but an ancestor
 * gets no leave when the cursor moves onto a nested descendant, so its overlay
 * lingers.
 *
 * This service holds exactly ONE active overlay. Every producer CLAIMS the slot
 * in its (deepest-gated) enter/drag handler and calls the returned release
 * callback on leave/drop. Because only the deepest target's handlers fire, the
 * latest claim is always the deepest target's overlay, so an ancestor's stale
 * claim is simply replaced — no leave needed. Consumers render purely off the
 * coordinator's read-only queries (`slotPreview`, `isActiveImageArg`), so two
 * overlays can never co-show.
 *
 * It does NOT own the dark-variant popover's show/hide timing — that stays a
 * FloatKit concern (hover-grace for cursor travel). The popover only re-claims
 * the same image-arg overlay (variant `"dark"`) so its tint doesn't collide
 * with a slot preview.
 */
export default class WireframeDragOverlay extends Service {
  @service wireframe;

  /**
   * The one active drag overlay (`#state.active`), or `null` when no target owns
   * the slot. Held inside a `#`-private reactive wrapper so the live, mutable
   * union is physically unreachable from outside this class — consumers read it
   * only through `slotPreview` (a frozen copy) and `isActiveImageArg` (a query).
   * A `trackedObject` because `@tracked` cannot decorate a `#` field.
   *
   * @type {{ active: ActiveDragOverlay|null }}
   */
  #state = trackedObject({ active: null });

  /**
   * Monotonic claim counter. Each claim stamps `active.seq` with the next
   * value; the release callback it returns closes over that seq and only
   * clears when it still matches, so a stale leave from a superseded claim is
   * a no-op.
   */
  #seq = 0;

  /**
   * Sticky dispatch payload for the active slot-insert, held so a drop can
   * dispatch it even after a dragleave cleared the visible overlay.
   *
   * @type {{action: string, args: Object}|null}
   */
  #stickyDispatch = null;

  /**
   * The active slot-insert, projected as a frozen, read-only copy (never the
   * live internal object), or `null` when the active overlay isn't a
   * slot-insert. Read by `DropPreview`.
   *
   * @returns {SlotPreview|null}
   */
  get slotPreview() {
    const a = this.#state.active;
    if (a?.kind !== "slot-insert") {
      return null;
    }
    return Object.freeze({
      previewKind: a.previewKind,
      validity: a.validity,
      label: a.label,
      geometry: Object.freeze({ ...a.geometry }),
    });
  }

  /**
   * Claims the overlay slot for a slot-insert preview, from a raw drop
   * descriptor (`{geometry, kind, validity, label, dispatch}`, as produced by
   * the container/grid resolvers). A `null` descriptor (cursor over an excluded
   * region) becomes an own-but-blank claim, so the deepest target still owns
   * the slot and a stale ancestor preview can't show.
   *
   * @param {SlotDropDescriptor|null} descriptor
   * @returns {() => void} Release callback for the matching leave.
   */
  claimSlotInsert(descriptor) {
    return this.#claim(
      descriptor
        ? {
            kind: "slot-insert",
            // The descriptor's own `kind` (insert/inside/replace/…) becomes
            // `previewKind` so it doesn't collide with the union discriminator.
            previewKind: descriptor.kind,
            geometry: descriptor.geometry,
            validity: descriptor.validity,
            label: descriptor.label,
            dispatch: descriptor.dispatch,
          }
        : null
    );
  }

  /**
   * Claims the overlay slot for an image-arg overlay (a filled image's
   * "overwrite" tint, the passive background fill, or the dark-variant
   * re-claim). Identified by `(blockKey, argName, isPassive)` so the owning
   * overlay can match it via `isActiveImageArg`.
   *
   * @param {ImageArgClaim} overlay
   * @returns {() => void} Release callback for the matching leave.
   */
  claimImageArg({ blockKey, argName, isPassive, variant = "light" }) {
    return this.#claim({
      kind: "image-arg",
      blockKey,
      argName,
      isPassive,
      variant,
    });
  }

  /**
   * Whether an image-arg overlay with the given identity is the active overlay.
   * Image-arg overlays render their tint off this (matching by identity, not a
   * token, so the dark popover's same-identity re-claim keeps the tint on). Pass
   * `variant` to additionally require a specific variant — e.g. ask "is the dark
   * variant of this arg active?" without reaching into the raw overlay object.
   *
   * @param {{blockKey: string, argName: string, isPassive: boolean, variant?: ("light"|"dark")}} identity
   * @returns {boolean}
   */
  isActiveImageArg({ blockKey, argName, isPassive, variant }) {
    const a = this.#state.active;
    return (
      a?.kind === "image-arg" &&
      a.blockKey === blockKey &&
      a.argName === argName &&
      a.isPassive === isPassive &&
      (variant === undefined || a.variant === variant)
    );
  }

  /**
   * Full reset on drag end (drop or cancel).
   */
  clear() {
    this.#state.active = null;
    this.#stickyDispatch = null;
  }

  /**
   * Runs the active slot-insert's dispatch at drop time, then clears it. Called
   * from a target's `onDrop` (before the deferred `endDrag` cleanup runs).
   *
   * @returns {boolean} `true` when an operation ran.
   */
  dispatch() {
    const payload = this.#stickyDispatch;
    this.#stickyDispatch = null;
    this.#state.active = null;
    if (!payload) {
      return false;
    }
    return this.wireframe.runDropDispatch(payload);
  }

  /**
   * Replaces the active overlay (latest claim wins). Returns a release callback
   * (mirroring `registerDragAndDropTarget` and friends) that clears the slot
   * only if this claim still holds it — so a stale leave from a superseded
   * claim is a safe no-op. Idempotent.
   *
   * @param {Object|null} overlay
   * @returns {() => void}
   */
  #claim(overlay) {
    const seq = ++this.#seq;
    this.#state.active = { ...(overlay ?? { kind: null }), seq };
    if (this.#state.active.kind === "slot-insert") {
      this.#stickyDispatch = overlay.dispatch ?? null;
    }
    return () => {
      if (this.#state.active?.seq === seq) {
        this.#state.active = null;
      }
    };
  }
}
