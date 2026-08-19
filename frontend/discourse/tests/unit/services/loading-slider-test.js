import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import sinon from "sinon";

module("Unit | Service | loading-slider", function (hooks) {
  setupTest(hooks);

  let clock;
  let loadingSlider;

  hooks.afterEach(function () {
    loadingSlider?.transitionEnded();
    clock?.restore();
  });

  test("can keep loading without showing the fallback spinner", function (assert) {
    clock = sinon.useFakeTimers({ now: Date.now(), shouldAdvanceTime: false });
    loadingSlider = this.owner.lookup("service:loading-slider");

    loadingSlider.transitionStarted();
    loadingSlider.transitionStarted({ showFallbackSpinner: false });
    clock.tick(3000);

    assert.false(
      loadingSlider.stillLoading,
      "a nested refresh can suppress the fallback spinner"
    );

    loadingSlider.transitionEnded();
    loadingSlider.transitionStarted();
    clock.tick(2001);

    assert.true(
      loadingSlider.stillLoading,
      "the default route-loading behavior still shows the fallback spinner"
    );
  });
});
