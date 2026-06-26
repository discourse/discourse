// @ts-check
import { registerDestructor } from "@ember/destroyable";
import { service } from "@ember/service";
import Modifier from "ember-modifier";

/**
 * Anchors a block badge (`wireframe-block-toolbar`) to the shared
 * `wireframe-toolbar-fit` coordinator so its actions fold into a hamburger when
 * the block is too narrow. A thin lifecycle bridge: it registers the badge's
 * chrome with the coordinator while the block is selected and unregisters when
 * it deselects or unmounts — all the measuring and tier-writing lives in the
 * service.
 *
 * Args (named):
 *  - `chromeEl` — the block's chrome element (the width the coordinator tracks).
 *    Captured on the chrome's `didInsert`, so it can be null on this modifier's
 *    first run; this re-runs and registers once it resolves.
 *  - `active` — whether the badge should be tracked (the block is selected).
 *  - `fingerprint` — a value that changes whenever the badge's rendered content
 *    changes width (a different action set, a relabelled handle, a locale
 *    switch). Read only to re-run this modifier so the coordinator re-measures;
 *    a plain resize is handled by the coordinator's observer instead.
 */
export default class ToolbarFitModifier extends Modifier {
  @service wireframeToolbarFit;

  /** @type {HTMLElement|null} The chrome currently registered, if any. */
  #chromeEl = null;

  constructor(owner, args) {
    super(owner, args);
    registerDestructor(this, (instance) => instance.#teardown());
  }

  modify(toolbarEl, _positional, { chromeEl, active, fingerprint }) {
    // Read purely to re-run when width-affecting content changes; value unused.
    void fingerprint;

    // The chrome ref can arrive late or change — drop the old registration.
    if (chromeEl !== this.#chromeEl) {
      this.#teardown();
      this.#chromeEl = chromeEl ?? null;
    }

    if (active && this.#chromeEl) {
      // Idempotent: re-registering re-measures, which is exactly what a
      // fingerprint-driven re-run wants.
      this.wireframeToolbarFit.register(this.#chromeEl, toolbarEl);
    } else {
      this.#teardown();
    }
  }

  #teardown() {
    if (this.#chromeEl) {
      this.wireframeToolbarFit.unregister(this.#chromeEl);
    }
  }
}
