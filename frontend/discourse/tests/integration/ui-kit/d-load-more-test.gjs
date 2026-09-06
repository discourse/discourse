import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { click, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import stubIntersectionObserver from "discourse/tests/helpers/stub-intersection-observer";
import DLoadMore, {
  disableLoadMoreObserver,
  enableLoadMoreObserver,
} from "discourse/ui-kit/d-load-more";

module("Integration | ui-kit | DLoadMore", function (hooks) {
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
        <DLoadMore @action={{performLoadMore}}>
          <table class="numbers">
            <tbody>
              <tr />
            </tbody>
          </table>
        </DLoadMore>
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
        <DLoadMore @action={{performLoadMore}} @enabled={{false}}>
          <table class="numbers">
            <tbody>
              <tr />
            </tbody>
          </table>
        </DLoadMore>
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
        <DLoadMore @action={{loadMore}} @isLoading={{true}}>
          <table class="numbers">
            <tbody>
              <tr />
            </tbody>
          </table>
        </DLoadMore>
      </template>
    );

    assert.strictEqual(
      this.observations.length,
      0,
      "does not create an IntersectionObserver while loading"
    );
    assert.strictEqual(actionCalled, 0, "does not call the loadMore action");
  });

  test("accepts an element as @root", async function (assert) {
    const loadMore = () => {};
    const root = document.createElement("div");

    await render(
      <template>
        <DLoadMore @action={{loadMore}} @root={{root}}>
          <div class="rows"></div>
        </DLoadMore>
      </template>
    );

    assert.strictEqual(
      this.observations[0].options.root,
      root,
      "observes within the element it was handed, rather than treating it as a selector"
    );
  });

  test("a @root captured after mount reaches the observer", async function (assert) {
    const loadMore = () => {};

    await render(
      class extends Component {
        @tracked root = null;

        @action
        attach() {
          this.root = document.querySelector(".scroll-container");
        }

        <template>
          <div class="scroll-container">
            <button {{on "click" this.attach}}>Attach</button>
            <DLoadMore @action={{loadMore}} @root={{this.root}}>
              <div class="rows"></div>
            </DLoadMore>
          </div>
        </template>
      }
    );

    assert.strictEqual(
      this.observations[0].options.root,
      document,
      "starts rooted at the document while no root is available"
    );

    await click("button");

    assert.strictEqual(
      this.observations.at(-1).options.root,
      document.querySelector(".scroll-container"),
      "re-observes within the root it was handed after mounting, rather than the null captured at construction"
    );
  });

  test("a changed @rootMargin reaches the observer", async function (assert) {
    const loadMore = () => {};

    await render(
      class extends Component {
        @tracked rootMargin = "10px";

        @action
        widen() {
          this.rootMargin = "500px";
        }

        <template>
          <button {{on "click" this.widen}}>Widen</button>
          <DLoadMore @action={{loadMore}} @rootMargin={{this.rootMargin}}>
            <div class="rows"></div>
          </DLoadMore>
        </template>
      }
    );

    assert.strictEqual(
      this.observations[0].options.rootMargin,
      "10px",
      "starts with the initial margin"
    );

    await click("button");

    assert.strictEqual(
      this.observations.at(-1).options.rootMargin,
      "500px",
      "re-observes with the updated margin instead of the one captured at construction"
    );
  });
});
