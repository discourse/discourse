import { tracked } from "@glimmer/tracking";
import { registerDestructor } from "@ember/destroyable";
import { next } from "@ember/runloop";
import Service from "@ember/service";
import { disableImplicitInjections } from "discourse/lib/implicit-injections";

@disableImplicitInjections
export default class ScrollStateService extends Service {
  @tracked _hideScrollableContentAboveCount = 0;
  @tracked _hideScrollableContentBelowCount = 0;

  get shouldHideContentAbove() {
    return this._hideScrollableContentAboveCount > 0;
  }

  get shouldHideContentBelow() {
    return this._hideScrollableContentBelowCount > 0;
  }

  hideScrollableContentAbove(destroyable) {
    next(() => this._hideScrollableContentAboveCount++);
    registerDestructor(destroyable, () => {
      // Deferred to avoid backtracking re-render assertion — the destructor
      // runs during the same render cycle that already read the counter.
      next(() => this._hideScrollableContentAboveCount--);
    });
  }

  hideScrollableContentBelow(destroyable) {
    next(() => this._hideScrollableContentBelowCount++);
    registerDestructor(destroyable, () => {
      next(() => this._hideScrollableContentBelowCount--);
    });
  }
}
