import Service from "@ember/service";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import pretender, { response } from "discourse/tests/helpers/create-pretender";

module("Unit | Controller | admin-site-traffic", function (hooks) {
  setupTest(hooks);

  test("refreshes use the loading slider after the initial result", async function (assert) {
    class LoadingSliderStub extends Service {
      starts = 0;
      ends = 0;
      startOptions = [];

      transitionStarted(options) {
        this.starts++;
        this.startOptions.push(options);
      }

      transitionEnded() {
        this.ends++;
      }
    }

    this.owner.register("service:loading-slider", LoadingSliderStub);
    pretender.get("/admin/dashboard/site-traffic-explorer.json", () =>
      response({ summary: {}, series: [], dimensions: {} })
    );
    const controller = this.owner.lookup("controller:admin-site-traffic");
    const loadingSlider = this.owner.lookup("service:loading-slider");

    await controller.fetchTraffic();

    assert.deepEqual(
      [loadingSlider.starts, loadingSlider.ends],
      [0, 0],
      "the initial request leaves the skeleton responsible for loading feedback"
    );

    await controller.fetchTraffic();

    assert.deepEqual(
      [loadingSlider.starts, loadingSlider.ends, loadingSlider.startOptions],
      [1, 1, [{ showFallbackSpinner: false }]],
      "later requests use only the loading slider"
    );

    controller.resetState();

    assert.strictEqual(
      loadingSlider.ends,
      1,
      "leaving the route does not stop an unrelated loading transition"
    );
  });
});
