import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { cancel } from "@ember/runloop";
import Service from "@ember/service";
import { disableImplicitInjections } from "discourse/lib/implicit-injections";
import discourseLater from "discourse-common/lib/later";
import { debounce } from "discourse-common/utils/decorators";

const INITIAL_DELAY_MS = 50;
const DEBOUNCE_MS = 5;

@disableImplicitInjections
export default class Docking extends Service {
  @tracked dockCheck = null;
  @tracked _initialTimer = null;
  @tracked _queuedTimer = null;

  constructor() {
    super(...arguments);

    window.addEventListener("scroll", this.queueDockCheck, { passive: true });
    document.addEventListener("touchmove", this.queueDockCheck, {
      passive: true,
    });

    // dockCheck might happen too early on full page refresh
    this._initialTimer = discourseLater(
      this,
      this._safeDockCheck,
      INITIAL_DELAY_MS
    );
  }

  @action
  initializeDockCheck(dockCheck) {
    this.dockCheck = dockCheck;
  }

  @debounce(DEBOUNCE_MS)
  queueDockCheck() {
    this._queuedTimer = this._safeDockCheck;
  }

  @action
  _safeDockCheck() {
    if (this.isDestroyed || this.isDestroying) {
      return;
    }
    this.dockCheck?.();
  }

  willDestroy() {
    this.willDestroy(...arguments);
    if (this._queuedTimer) {
      cancel(this._queuedTimer);
    }

    cancel(this._initialTimer);
    window.removeEventListener("scroll", this.queueDockCheck);
    document.removeEventListener("touchmove", this.queueDockCheck);
  }
}
