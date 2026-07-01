import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import DSheet from "discourse/float-kit/components/d-sheet";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

module("Integration | Component | FloatKit | d-scroll", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    this.originalResizeObserver = window.ResizeObserver;
    this.observedElements = [];

    const observedElements = this.observedElements;

    class MockResizeObserver {
      observe(element) {
        observedElements.push(element);
      }

      unobserve(element) {
        const index = observedElements.indexOf(element);
        if (index !== -1) {
          observedElements.splice(index, 1);
        }
      }

      disconnect() {
        observedElements.length = 0;
      }
    }

    window.ResizeObserver = MockResizeObserver;
    globalThis.ResizeObserver = MockResizeObserver;
  });

  hooks.afterEach(function () {
    window.ResizeObserver = this.originalResizeObserver;
    globalThis.ResizeObserver = this.originalResizeObserver;
  });

  test("observes the view, content, and spacers for overflow changes", async function (assert) {
    await render(
      <template>
        <DSheet.Scroll.Root as |scroll|>
          <DSheet.Scroll.View @controller={{scroll}}>
            <DSheet.Scroll.Content @controller={{scroll}}>
              <p>Content</p>
            </DSheet.Scroll.Content>
          </DSheet.Scroll.View>
        </DSheet.Scroll.Root>
      </template>
    );

    assert.true(
      this.observedElements.includes(
        document.querySelector("[data-d-scroll~='scroll-container']")
      ),
      "the scroll container is observed"
    );
    assert.true(
      this.observedElements.includes(
        document.querySelector("[data-d-scroll~='content']")
      ),
      "the content is observed"
    );
    assert.true(
      this.observedElements.includes(
        document.querySelector("[data-d-scroll~='start-spacer']")
      ),
      "the start spacer is observed"
    );
    assert.true(
      this.observedElements.includes(
        document.querySelector("[data-d-scroll~='end-spacer']")
      ),
      "the end spacer is observed"
    );
  });
});
