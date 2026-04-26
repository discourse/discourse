import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import LoadMore, {
  disableLoadMoreObserver,
  enableLoadMoreObserver,
} from "discourse/components/load-more";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import stubIntersectionObserver from "discourse/tests/helpers/stub-intersection-observer";

module("Integration | Component | load-more", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    enableLoadMoreObserver();
    this.observations = stubIntersectionObserver();
  });

  hooks.afterEach(function () {
    disableLoadMoreObserver();
  });

  test("calls loadMore action when intersection occurs", async function (assert) {
    let actionCalled = 0;
    const performLoadMore = () => {
      actionCalled++;
    };

    await render(
      <template>
        <LoadMore @action={{performLoadMore}}>
          <table class="numbers">
            <tbody>
              <tr />
            </tbody>
          </table>
        </LoadMore>
      </template>
    );

    await this.observations[0]?.trigger();

    assert.strictEqual(actionCalled, 1, "calls the loadMore action once");
  });

  test("does not call loadMore action if intersection occurs and this is not enabled", async function (assert) {
    let actionCalled = 0;
    const performLoadMore = () => {
      actionCalled++;
    };

    await render(
      <template>
        <LoadMore @action={{performLoadMore}} @enabled={{false}}>
          <table class="numbers">
            <tbody>
              <tr />
            </tbody>
          </table>
        </LoadMore>
      </template>
    );

    await this.observations[0]?.trigger();

    assert.strictEqual(actionCalled, 0, "does not call the loadMore action");
  });

  test("does not call loadMore action when isLoading is true", async function (assert) {
    let actionCalled = 0;
    const loadMore = () => actionCalled++;

    await render(
      <template>
        <LoadMore @action={{loadMore}} @isLoading={{true}}>
          <table class="numbers">
            <tbody>
              <tr />
            </tbody>
          </table>
        </LoadMore>
      </template>
    );

    assert.strictEqual(
      this.observations.length,
      0,
      "does not create an IntersectionObserver while loading"
    );
    assert.strictEqual(actionCalled, 0, "does not call the loadMore action");
  });
});
