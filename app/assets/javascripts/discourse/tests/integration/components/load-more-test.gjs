import { render, waitUntil } from "@ember/test-helpers";
import { module, test } from "qunit";
import LoadMore, {
  disableLoadMoreObserver,
  enableLoadMoreObserver,
} from "discourse/components/load-more";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

module("Integration | Component | load-more", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    enableLoadMoreObserver();
    this.originalIntersectionObserver = window.IntersectionObserver;

    window.IntersectionObserver = class MockIntersectionObserver {
      callback;

      constructor(callback) {
        this.callback = callback;
      }

      observe(element) {
        if (element) {
          // Simulate intersection in next run loop
          setTimeout(() => {
            this.callback([
              {
                target: element,
                isIntersecting: true,
              },
            ]);
          }, 0);
        }
      }

      unobserve() {}
      disconnect() {}
    };
  });

  hooks.afterEach(function () {
    window.IntersectionObserver = this.originalIntersectionObserver;
    disableLoadMoreObserver();
  });

  test("calls loadMore action when intersection occurs", async function (assert) {
    let actionCalled = 0;
    const performLoadMore = () => {
      actionCalled++;
    };

    await render(
      <template>
        <LoadMore @action={{performLoadMore}} @root="#ember-testing">
          <table class="numbers">
            <tbody>
              <tr />
            </tbody>
          </table>
        </LoadMore>
      </template>
    );

    await waitUntil(() => actionCalled === 1);

    assert.strictEqual(
      actionCalled,
      1,
      "loadMore action should be called once"
    );
  });

  test("does not call loadMore action if intersection occurs and this is not enabled", async function (assert) {
    let actionCalled = 0;
    const performLoadMore = () => {
      actionCalled++;
    };

    await render(
      <template>
        <LoadMore
          @action={{performLoadMore}}
          @root="#ember-testing"
          @enabled={{false}}
        >
          <table class="numbers">
            <tbody>
              <tr />
            </tbody>
          </table>
        </LoadMore>
      </template>
    );

    assert.strictEqual(
      actionCalled,
      0,
      "loadMore action should be called never"
    );
  });
});
