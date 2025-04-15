import { render, settled } from "@ember/test-helpers";
import { module, test } from "qunit";
import LoadMore from "discourse/components/load-more";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

module("Integration | Component | load-more", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
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
  });

  test("calls loadMore action when intersection occurs", async function (assert) {
    let actionCalled = 0;
    const performLoadMore = () => {
      actionCalled++;
    };

    await render(
      <template>
        <LoadMore
          @selector=".numbers tr"
          @action={{performLoadMore}}
          @root="#ember-testing"
        >
          <table class="numbers">
            <tbody>
              <tr />
            </tbody>
          </table>
        </LoadMore>
      </template>
    );

    // eslint-disable-next-line ember/no-settled-after-test-helper
    await settled();

    assert.strictEqual(
      actionCalled,
      1,
      "loadMore action should be called once"
    );
  });
});
