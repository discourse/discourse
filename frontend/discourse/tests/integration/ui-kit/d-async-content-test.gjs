import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { click, render, rerender, settled, waitFor } from "@ember/test-helpers";
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

    test("it surfaces a synchronous throw", async function (assert) {
      const load = () => {
        throw new Error("sync failure");
      };

      await render(
        <template>
          <DAsyncContent @asyncData={{load}}>
            <:content as |data|>
              <div class="content">{{data}}</div>
            </:content>
            <:error as |error|>
              <div class="error">{{error.message}}</div>
            </:error>
          </DAsyncContent>
        </template>
      );

      assert
        .dom(".error")
        .hasText(
          "sync failure",
          "a throw becomes a rejection instead of escaping the getter and breaking the render"
        );
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

  // Drives the debounced tests from outside a component, so state can be changed
  // without `click` awaiting the debounce timer in between.
  class DebounceState {
    @tracked context = "first";
    @tracked rendered = true;
    @tracked debounce = true;
    @tracked source = null;
  }

  module("@debounce", function () {
    // The debounced path only engages from the second evaluation onward, so this asserts
    // after a context change rather than on first render.
    test("it accepts a synchronous source", async function (assert) {
      await render(
        class extends Component {
          @tracked context = "first";

          load = (context) => context;

          @action
          changeContext() {
            this.context = "second";
          }

          <template>
            <button {{on "click" this.changeContext}}>Change Context</button>
            <DAsyncContent
              @asyncData={{this.load}}
              @context={{this.context}}
              @debounce={{true}}
            >
              <:content as |data|>
                <div class="content">{{data}}</div>
              </:content>
            </DAsyncContent>
          </template>
        }
      );

      assert.dom(".content").hasText("first");

      await click("button");

      assert
        .dom(".content")
        .hasText("second", "a plain value settles the debounced promise");
    });

    test("it surfaces a synchronous throw", async function (assert) {
      await render(
        class extends Component {
          @tracked context = "first";

          load = (context) => {
            if (context === "second") {
              throw new Error("sync failure");
            }

            return context;
          };

          @action
          changeContext() {
            this.context = "second";
          }

          <template>
            <button {{on "click" this.changeContext}}>Change Context</button>
            <DAsyncContent
              @asyncData={{this.load}}
              @context={{this.context}}
              @debounce={{true}}
            >
              <:content as |data|>
                <div class="content">{{data}}</div>
              </:content>
              <:error as |error|>
                <div class="error">{{error.message}}</div>
              </:error>
            </DAsyncContent>
          </template>
        }
      );

      assert.dom(".content").hasText("first");

      await click("button");

      assert
        .dom(".error")
        .hasText(
          "sync failure",
          "a throw rejects the debounced promise instead of escaping it unsettled"
        );
    });

    test("it does not retain stale content after a synchronous throw", async function (assert) {
      await render(
        class extends Component {
          @tracked context = "first";

          load = (context) => {
            if (context === "second") {
              throw new Error("sync failure");
            }

            return context;
          };

          @action
          changeContext() {
            this.context = "second";
          }

          <template>
            <button {{on "click" this.changeContext}}>Change Context</button>
            <DAsyncContent
              @asyncData={{this.load}}
              @context={{this.context}}
              @debounce={{true}}
              @retainWhileReloading={{true}}
            >
              <:content as |data|>
                <div class="content">{{data}}</div>
              </:content>
              <:error as |error|>
                <div class="error">{{error.message}}</div>
              </:error>
            </DAsyncContent>
          </template>
        }
      );

      assert.dom(".content").hasText("first");

      await click("button");

      assert.dom(".error").hasText("sync failure");
      assert
        .dom(".content")
        .doesNotExist(
          "a reload that never settles would leave the stale value on screen"
        );
    });

    test("it does not debounce the first evaluation", async function (assert) {
      const load = (context) => context;

      const renderPromise = render(
        <template>
          <div data-async-content-test>
            <DAsyncContent
              @asyncData={{load}}
              @context="first"
              @debounce={{true}}
            >
              <:content as |data|>
                <div class="content">{{data}}</div>
              </:content>
            </DAsyncContent>
          </div>
        </template>
      );

      // Asserting before the render settles, so the transient loading phase is
      // observable: a debounced first evaluation would delay the initial paint.
      await waitFor("[data-async-content-test]");

      assert.dom(".spinner").doesNotExist();
      assert
        .dom(".content")
        .hasText("first", "a sync source resolves without waiting out a delay");

      await renderPromise;
    });

    test("it honors a changed @debounce on the next evaluation", async function (assert) {
      await render(
        class extends Component {
          @tracked context = "first";
          @tracked debounce = false;

          // Both in one action, so a single evaluation sees the new `@debounce`
          // together with the new `@context`. Flipping `@debounce` on its own
          load = (context) => context;

          // would trigger an evaluation of its own that masks the defect.
          @action
          enableDebounceAndChangeContext() {
            this.debounce = true;
            this.context = "second";
          }

          <template>
            <button
              class="change"
              {{on "click" this.enableDebounceAndChangeContext}}
            >
              Change
            </button>
            <DAsyncContent
              @asyncData={{this.load}}
              @context={{this.context}}
              @debounce={{this.debounce}}
            >
              <:content as |data|>
                <div class="content">{{data}}</div>
              </:content>
            </DAsyncContent>
          </template>
        }
      );

      const changePromise = click(".change");

      // The debounced path wraps a sync source in a promise, so a pending phase
      // appears only if the new `@debounce` was read for this evaluation rather
      // than carried over from the previous one.
      await waitFor(".spinner");
      assert.dom(".spinner").exists();

      await changePromise;
      assert.dom(".content").hasText("second");
    });

    // The un-debounced path calls `@asyncData` inside the cached computation, so state it
    // reads is autotracked; the debounced path calls it from a timer, where it cannot be.
    // Consumers that debounce must therefore fold every reactive dependency into
    // `@context` instead of relying on the function to track it. These two pin that
    // asymmetry: without the un-debounced case the debounced assertion would also hold
    // for a source that simply never re-runs.
    test("an un-debounced source autotracks state read inside the function", async function (assert) {
      await render(
        class extends Component {
          @tracked suffix = "a";

          load = () => `value-${this.suffix}`;

          @action
          changeSuffix() {
            this.suffix = "b";
          }

          <template>
            <button {{on "click" this.changeSuffix}}>Suffix</button>
            <DAsyncContent @asyncData={{this.load}}>
              <:content as |data|>
                <div class="content">{{data}}</div>
              </:content>
            </DAsyncContent>
          </template>
        }
      );

      assert.dom(".content").hasText("value-a");

      await click("button");

      assert
        .dom(".content")
        .hasText("value-b", "the reload picks up the new value");
    });

    test("a debounced source does not autotrack state read inside the function", async function (assert) {
      await render(
        class extends Component {
          @tracked context = "first";
          @tracked suffix = "a";

          load = (context) => `${context}-${this.suffix}`;

          @action
          changeContext() {
            this.context = "second";
          }

          @action
          changeSuffix() {
            this.suffix = "b";
          }

          <template>
            <button
              class="context"
              {{on "click" this.changeContext}}
            >Context</button>
            <button
              class="suffix"
              {{on "click" this.changeSuffix}}
            >Suffix</button>
            <DAsyncContent
              @asyncData={{this.load}}
              @context={{this.context}}
              @debounce={{true}}
            >
              <:content as |data|>
                <div class="content">{{data}}</div>
              </:content>
            </DAsyncContent>
          </template>
        }
      );

      assert.dom(".content").hasText("first-a");

      // Engages the debounced path, which applies from the second evaluation onward.
      await click(".context");
      assert.dom(".content").hasText("second-a");

      await click(".suffix");

      assert
        .dom(".content")
        .hasText(
          "second-a",
          "a dependency read only inside the debounced call does not restart the load"
        );
    });

    // The first evaluation runs un-debounced, so it reaches the source through the
    // direct call rather than the promise executor. A throw there must still reject.
    test("it surfaces a synchronous throw on the first evaluation", async function (assert) {
      const load = () => {
        throw new Error("sync failure");
      };

      await render(
        <template>
          <DAsyncContent
            @asyncData={{load}}
            @context="first"
            @debounce={{true}}
          >
            <:content as |data|>
              <div class="content">{{data}}</div>
            </:content>
            <:error as |error|>
              <div class="error">{{error.message}}</div>
            </:error>
          </DAsyncContent>
        </template>
      );

      assert
        .dom(".error")
        .hasText(
          "sync failure",
          "the un-debounced first evaluation routes a throw to the error block too"
        );
    });

    test("it debounces an asynchronous source", async function (assert) {
      await render(
        class extends Component {
          @tracked context = "first";

          load = async (context) => context;

          @action
          changeContext() {
            this.context = "second";
          }

          <template>
            <button {{on "click" this.changeContext}}>Change Context</button>
            <DAsyncContent
              @asyncData={{this.load}}
              @context={{this.context}}
              @debounce={{true}}
            >
              <:content as |data|>
                <div class="content">{{data}}</div>
              </:content>
            </DAsyncContent>
          </template>
        }
      );

      assert.dom(".content").hasText("first");

      await click("button");

      assert
        .dom(".content")
        .hasText("second", "a promise source settles the debounced promise");
    });

    // `rerender` flushes the render without waiting out the debounce timer, so each
    // assignment below produces its own evaluation and they all land inside a single
    // window. `settled` then completes only if every superseded evaluation settled its
    // promise: an abandoned one would keep an async waiter pending and hang the test.
    test("it coalesces evaluations inside one window into a single call", async function (assert) {
      const seen = [];
      const state = new DebounceState();

      const load = (context) => {
        seen.push(context);
        return context;
      };

      await render(
        <template>
          <DAsyncContent
            @asyncData={{load}}
            @context={{state.context}}
            @debounce={{true}}
          >
            <:content as |data|>
              <div class="content">{{data}}</div>
            </:content>
          </DAsyncContent>
        </template>
      );

      assert.deepEqual(
        seen,
        ["first"],
        "the first evaluation runs immediately"
      );

      for (const next of ["a", "b", "c"]) {
        state.context = next;
        await rerender();
      }

      await settled();

      assert.deepEqual(
        seen,
        ["first", "c"],
        "the superseded evaluations never reach the source"
      );
      assert.dom(".content").hasText("c");
    });

    // Turning `@debounce` off makes the next evaluation take the direct path, which must
    // still drop the call the previous evaluation left waiting on its timer.
    test("it drops a scheduled call when the next evaluation is not debounced", async function (assert) {
      const seen = [];
      const state = new DebounceState();

      const load = (context) => {
        seen.push(context);
        return context;
      };

      await render(
        <template>
          <DAsyncContent
            @asyncData={{load}}
            @context={{state.context}}
            @debounce={{state.debounce}}
          >
            <:content as |data|>
              <div class="content">{{data}}</div>
            </:content>
          </DAsyncContent>
        </template>
      );

      assert.deepEqual(seen, ["first"]);

      // Schedules a debounced call for "second"...
      state.context = "second";
      await rerender();

      // ...which this evaluation supersedes before the timer fires.
      state.debounce = false;
      state.context = "third";
      await rerender();

      await settled();

      assert.deepEqual(
        seen,
        ["first", "third"],
        "the superseded call never reaches the source"
      );
      assert.dom(".content").hasText("third");
    });

    // Replacing `@asyncData` outright must drop a scheduled call just as a new context
    // does, for every shape the argument accepts.
    test("it drops a scheduled call when @asyncData is replaced by a promise", async function (assert) {
      const seen = [];
      const state = new DebounceState();
      state.source = (context) => {
        seen.push(context);
        return context;
      };

      await render(
        <template>
          <DAsyncContent
            @asyncData={{state.source}}
            @context={{state.context}}
            @debounce={{true}}
          >
            <:content as |data|>
              <div class="content">{{data}}</div>
            </:content>
          </DAsyncContent>
        </template>
      );

      assert.deepEqual(seen, ["first"]);

      state.context = "second";
      await rerender();

      state.source = Promise.resolve("replacement");
      await rerender();

      await settled();

      assert.deepEqual(
        seen,
        ["first"],
        "the superseded call never reaches the source"
      );
      assert.dom(".content").hasText("replacement");
    });

    test("it drops a scheduled call when @asyncData is replaced by a TrackedAsyncData", async function (assert) {
      const seen = [];
      const state = new DebounceState();
      state.source = (context) => {
        seen.push(context);
        return context;
      };

      await render(
        <template>
          <DAsyncContent
            @asyncData={{state.source}}
            @context={{state.context}}
            @debounce={{true}}
          >
            <:content as |data|>
              <div class="content">{{data}}</div>
            </:content>
          </DAsyncContent>
        </template>
      );

      assert.deepEqual(seen, ["first"]);

      state.context = "second";
      await rerender();

      state.source = new TrackedAsyncData(Promise.resolve("replacement"));
      await rerender();

      await settled();

      assert.deepEqual(
        seen,
        ["first"],
        "the superseded call never reaches the source"
      );
      assert.dom(".content").hasText("replacement");
    });

    test("it does not invoke a debounced source after the component is destroyed", async function (assert) {
      const seen = [];
      const state = new DebounceState();

      const load = (context) => {
        seen.push(context);
        return context;
      };

      await render(
        <template>
          {{#if state.rendered}}
            <DAsyncContent
              @asyncData={{load}}
              @context={{state.context}}
              @debounce={{true}}
            >
              <:content as |data|>
                <div class="content">{{data}}</div>
              </:content>
            </DAsyncContent>
          {{/if}}
        </template>
      );

      assert.deepEqual(seen, ["first"]);

      // Schedule a debounced load, then tear the component down before its timer fires.
      state.context = "second";
      await rerender();
      state.rendered = false;

      await settled();

      assert.deepEqual(
        seen,
        ["first"],
        "the scheduled load is cancelled rather than running against a dead component"
      );
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
