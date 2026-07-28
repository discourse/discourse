import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { click, render, settled, waitFor } from "@ember/test-helpers";
import { TrackedAsyncData } from "ember-async-data";
import { module, test } from "qunit";
import { Promise as RsvpPromise } from "rsvp";
import sinon from "sinon";
import DialogHolder from "discourse/dialog-holder/components/dialog-holder";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import DAsyncContent from "discourse/ui-kit/d-async-content";

module("Integration | ui-kit | DAsyncContent", function (hooks) {
  setupRenderingTest(hooks);

  module("@asyncData", function () {
    test("it accepts a promise", async function (assert) {
      const promise = Promise.resolve("data");

      await render(
        <template>
          <DAsyncContent @asyncData={{promise}}>
            <:content as |data|>
              <div class="content">{{data}}</div>
            </:content>
          </DAsyncContent>
        </template>
      );

      assert.true(true, "no error is thrown");
      assert.dom(".content").hasText("data");
    });

    test("it accepts a function that returns a promise", async function (assert) {
      const promise = () => Promise.resolve("data");

      await render(
        <template>
          <DAsyncContent @asyncData={{promise}}>
            <:content as |data|>
              <div class="content">{{data}}</div>
            </:content>
          </DAsyncContent>
        </template>
      );

      assert.true(true, "no error is thrown");
      assert.dom(".content").hasText("data");
    });

    test("it accepts an RsvpPromise", async function (assert) {
      const promise = RsvpPromise.resolve("data");

      await render(
        <template>
          <DAsyncContent @asyncData={{promise}}>
            <:content as |data|>
              <div class="content">{{data}}</div>
            </:content>
          </DAsyncContent>
        </template>
      );

      assert.dom(".content").hasText("data");
    });

    test("it accepts an async function", async function (assert) {
      const promise = async () => "data";

      await render(
        <template>
          <DAsyncContent @asyncData={{promise}}>
            <:content as |data|>
              <div class="content">{{data}}</div>
            </:content>
          </DAsyncContent>
        </template>
      );

      assert.dom(".content").hasText("data");
    });

    test("it accepts an instance of TrackedAsyncData", async function (assert) {
      const promise = new TrackedAsyncData(Promise.resolve("data"));

      await render(
        <template>
          <DAsyncContent @asyncData={{promise}}>
            <:content as |data|>
              <div class="content">{{data}}</div>
            </:content>
          </DAsyncContent>
        </template>
      );

      assert.dom(".content").hasText("data");
    });
  });

  module("@context", function () {
    test("it passes the context to the async function", async function (assert) {
      const promise = (context) => {
        assert.strictEqual(context, "correct", "context is passed correctly");
        return Promise.resolve("data");
      };

      await render(
        <template>
          <DAsyncContent @asyncData={{promise}} @context="correct">
            <:content as |data|>
              <div class="content">{{data}}</div>
            </:content>
          </DAsyncContent>
        </template>
      );

      assert.dom(".content").hasText("data");
    });

    test("it updates the async data when the context changes", async function (assert) {
      await render(
        class extends Component {
          @tracked context = "first";

          @action
          changeContext() {
            this.context = "second";
          }

          async load(context) {
            return context;
          }

          <template>
            <button {{on "click" this.changeContext}}>Change Context</button>
            <DAsyncContent @asyncData={{this.load}} @context={{this.context}}>
              <:content as |data|>
                <div class="content">{{data}}</div>
              </:content>
            </DAsyncContent>
          </template>
        }
      );

      assert.dom(".content").hasText("first");

      await click("button");

      assert.dom(".content").hasText("second");
    });
  });

  module("<:loading>", function () {
    test("it displays the spinner when the block is not provided", async function (assert) {
      let resolvePromise;
      const promise = new Promise((resolve) => (resolvePromise = resolve));

      const renderPromise = render(
        <template>
          <div data-async-content-test>
            <DAsyncContent @asyncData={{promise}}>
              <:content>
                <div class="content"></div>
              </:content>
            </DAsyncContent>
          </div>
        </template>
      );

      // TrackedAsyncData is tangled with Ember's run loop, so we need to wait for the result of the rendering
      // instead to check the loading state.
      // Otherwise, the test will timeout waiting for the promise to resolve.
      await waitFor("[data-async-content-test]");
      assert.dom(".spinner").exists();

      resolvePromise();
      await renderPromise;
      assert.dom(".content").exists();
    });

    test("it displays the block when provided", async function (assert) {
      let resolvePromise;
      const promise = new Promise((resolve) => (resolvePromise = resolve));

      const renderPromise = render(
        <template>
          <div data-async-content-test>
            <DAsyncContent @asyncData={{promise}}>
              <:loading>
                <div class="loading-provided"></div>
              </:loading>

              <:content>
                <div class="content"></div>
              </:content>
            </DAsyncContent>
          </div>
        </template>
      );

      // TrackedAsyncData is tangled with Ember's run loop, so we need to wait for the result of the rendering
      // instead to check the loading state.
      // Otherwise, the test will timeout waiting for the promise to resolve.
      await waitFor("[data-async-content-test]");
      assert.dom(".loading-provided").exists();

      resolvePromise();
      await renderPromise;
      assert.dom(".content").exists();
    });
  });

  module("<:content>", function () {
    test("it displays the block once the promise is fulfilled", async function (assert) {
      const promise = Promise.resolve("data returned");

      await render(
        <template>
          <DAsyncContent @asyncData={{promise}}>
            <:content as |data|>
              <div class="content">
                {{data}}
              </div>
            </:content>
          </DAsyncContent>
        </template>
      );

      assert.dom(".content").exists();
      assert.dom(".content").hasText("data returned");
    });

    test("it does not display the block if the promise fails", async function (assert) {
      const stub = sinon.stub(console, "error");
      const promise = Promise.reject("error");

      await render(
        <template>
          <DAsyncContent @asyncData={{promise}}>
            <:content as |data|>
              <div class="content">
                {{data}}
              </div>
            </:content>
          </DAsyncContent>
        </template>
      );

      assert.dom(".content").doesNotExist();
      assert.true(stub.calledWith("error"));

      stub.restore();
    });
  });

  module("<:empty>", function () {
    test("it displays the block when the promise is resolved with an empty value", async function (assert) {
      const promise = Promise.resolve(null);

      await render(
        <template>
          <DAsyncContent @asyncData={{promise}}>
            <:empty>
              <div class="empty">
                Empty
              </div>
            </:empty>
          </DAsyncContent>
        </template>
      );

      assert.dom(".empty").exists();
    });

    test("it does not display the block when the promise is resolved with a value", async function (assert) {
      const promise = Promise.resolve("data");

      await render(
        <template>
          <DAsyncContent @asyncData={{promise}}>
            <:empty>
              <div class="empty">
                Empty
              </div>
            </:empty>
          </DAsyncContent>
        </template>
      );

      assert.dom(".empty").doesNotExist();
    });

    test("it displays the content block if the empty block is not provided", async function (assert) {
      const promise = Promise.resolve(null);

      await render(
        <template>
          <DAsyncContent @asyncData={{promise}}>
            <:content>
              <div class="content">
                Empty
              </div>
            </:content>
          </DAsyncContent>
        </template>
      );

      assert.dom(".content").exists();
    });

    test("it does not display the block if the promise fails", async function (assert) {
      const stub = sinon.stub(console, "error");
      const promise = Promise.reject("error");

      await render(
        <template>
          <DAsyncContent @asyncData={{promise}}>
            <:empty>
              <div class="empty">
                Empty
              </div>
            </:empty>
          </DAsyncContent>
        </template>
      );

      assert.dom(".empty").doesNotExist();
      assert.true(stub.calledWith("error"));

      stub.restore();
    });
  });

  module("<:error>", function () {
    test("it displays an inline error when the block is not provided", async function (assert) {
      const stub = sinon.stub(console, "error");
      const promise = Promise.reject("error");

      await render(
        <template><DAsyncContent @asyncData={{promise}} /></template>
      );

      assert.dom(".alert-error").exists();
      assert.dom(".alert-error").hasText("Sorry, an error has occurred.");
      assert.true(stub.calledWith("error"));

      stub.restore();
    });

    test("it displays a popup error dialog when the block is not provided", async function (assert) {
      const stub = sinon.stub(console, "error");
      const promise = Promise.reject("error");

      await render(
        <template>
          <DAsyncContent @asyncData={{promise}} @errorMode="popup" />
          <DialogHolder />
        </template>
      );

      assert.dom(".dialog-body").exists();
      assert.dom(".dialog-body").hasText("Sorry, an error has occurred.");
      assert.true(stub.calledWith("error"));

      stub.restore();
    });

    test("it displays the block when the promise is rejected", async function (assert) {
      const promise = Promise.reject("error");

      await render(
        <template>
          <DAsyncContent @asyncData={{promise}}>
            <:error as |error|>
              <div class="error">
                {{error}}
              </div>
            </:error>
          </DAsyncContent>
        </template>
      );

      assert.dom(".error").exists();
      assert.dom(".error").hasText("error");
    });

    test("it passes the inline error message as a component when the promise is rejected", async function (assert) {
      const stub = sinon.stub(console, "error");
      const promise = Promise.reject("error");

      await render(
        <template>
          <DAsyncContent @asyncData={{promise}}>
            <:error as |error AsyncContentInlineErrorMessage|>
              <div class="error">
                <AsyncContentInlineErrorMessage />
              </div>
            </:error>
          </DAsyncContent>
        </template>
      );

      assert.dom(".error").exists();

      assert.dom(".alert-error").exists();
      assert.dom(".alert-error").hasText("Sorry, an error has occurred.");
      assert.true(stub.calledWith("error"));

      stub.restore();
    });

    test("it does not display the block when the promise is resolved", async function (assert) {
      const promise = Promise.resolve("data");

      await render(
        <template>
          <DAsyncContent @asyncData={{promise}}>
            <:error as |error|>
              <div class="error">
                {{error}}
              </div>
            </:error>
          </DAsyncContent>
        </template>
      );

      assert.dom(".error").doesNotExist();
    });

    test("it does not display the block when the promise is resolved with an empty value", async function (assert) {
      const promise = Promise.resolve(null);

      await render(
        <template>
          <DAsyncContent @asyncData={{promise}}>
            <:error as |error|>
              <div class="error">
                {{error}}
              </div>
            </:error>
          </DAsyncContent>
        </template>
      );

      assert.dom(".error").doesNotExist();
    });
  });

  module("@retainWhileReloading", function () {
    test("keeps the resolved content mounted while a later load is pending", async function (assert) {
      let buildCount = 0;
      let resolveSecond;
      let host;

      // Counts constructions so we can prove the content subtree is not torn
      // down and rebuilt across a reload.
      class CountingContent extends Component {
        constructor() {
          super(...arguments);
          buildCount++;
        }

        <template>
          <div class="counting-content">{{@value}}</div>
        </template>
      }

      class Host extends Component {
        // Start already-resolved so the initial render settles without us
        // having to await a pending promise. Reassigned from the test body via
        // the captured `host` reference, which the lint rule can't see.
        // eslint-disable-next-line discourse/no-unnecessary-tracked
        @tracked asyncData = Promise.resolve("v1");

        constructor() {
          super(...arguments);
          // Captured so the test can swap `asyncData` directly.
          host = this;
        }

        <template>
          <DAsyncContent
            @asyncData={{this.asyncData}}
            @retainWhileReloading={{true}}
          >
            <:loading>
              <div class="provided-loading"></div>
            </:loading>
            <:content as |value|>
              <CountingContent @value={{value}} />
            </:content>
          </DAsyncContent>
        </template>
      }

      await render(<template><Host /></template>);
      assert.dom(".counting-content").hasText("v1", "first value renders");
      assert.strictEqual(buildCount, 1, "content built once initially");

      // Reload with a promise that stays pending across a render. We poll the
      // DOM with `waitFor` rather than awaiting `settled`/`rerender`, which
      // would block on the pending `TrackedAsyncData`'s async waiter.
      host.asyncData = new Promise((resolve) => (resolveSecond = resolve));
      await waitFor(".counting-content");

      // Because the content is retained (never unmounted for the loading
      // state), `waitFor` finds it immediately and no loading block renders.
      assert
        .dom(".provided-loading")
        .doesNotExist("no loading state on reload");
      assert
        .dom(".counting-content")
        .hasText("v1", "previous content retained while pending");
      assert.strictEqual(
        buildCount,
        1,
        "content instance is not rebuilt during the pending reload"
      );

      resolveSecond("v2");
      await settled();

      assert.dom(".counting-content").hasText("v2", "new value swaps in");
      assert.strictEqual(
        buildCount,
        1,
        "content instance survived the reload (not torn down)"
      );
    });
  });

  module("synchronous sources and cancellation", function () {
    test("a synchronous return renders content with no loading phase", async function (assert) {
      const load = () => ["a", "b"];

      await render(
        <template>
          <DAsyncContent @asyncData={{load}}>
            <:loading><div class="the-loading"></div></:loading>
            <:content as |rows|>
              <div class="the-content">{{rows.length}}</div>
            </:content>
          </DAsyncContent>
        </template>
      );

      assert
        .dom(".the-loading")
        .doesNotExist("a synchronous value never shows the loading state");
      assert
        .dom(".the-content")
        .hasText("2", "the synchronous value renders immediately as content");
    });

    test("passes an AbortSignal and aborts the prior request when the context changes", async function (assert) {
      const signals = [];

      class Host extends Component {
        @tracked term = "a";

        // Records each call's signal so we can assert the superseded request is
        // aborted. Resolves immediately so `settled` never blocks on a waiter.
        load = (context, { signal }) => {
          signals.push(signal);
          return Promise.resolve([]);
        };

        @action
        retype() {
          this.term = "ab";
        }

        <template>
          <button
            class="retype"
            type="button"
            {{on "click" this.retype}}
          >x</button>
          <DAsyncContent @asyncData={{this.load}} @context={{this.term}}>
            <:content as |v|>{{v.length}}</:content>
          </DAsyncContent>
        </template>
      }

      await render(<template><Host /></template>);
      assert.strictEqual(
        signals.length,
        1,
        "the async function receives a signal"
      );
      assert.false(signals[0].aborted, "the first request starts un-aborted");

      await click(".retype");
      assert.strictEqual(
        signals.length,
        2,
        "a context change starts a new request"
      );
      assert.true(
        signals[0].aborted,
        "the superseded request's signal is aborted"
      );
      assert.false(signals[1].aborted, "the latest request stays active");
    });
  });
});
