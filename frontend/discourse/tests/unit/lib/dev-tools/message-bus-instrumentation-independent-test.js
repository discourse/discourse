import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import {
  install,
  messageBusState,
  subscriptions,
  uninstall,
} from "discourse/static/dev-tools/message-bus/instrumentation";

function callbackChannels(bus) {
  return bus.callbacks.map(({ channel }) => channel);
}

module(
  "Unit | Lib | dev-tools | message-bus-instrumentation-independent",
  function (hooks) {
    setupTest(hooks);

    hooks.beforeEach(function () {
      uninstall();

      this.bus = window.MessageBus;
      this.originalCallbacks = [...this.bus.callbacks];
      this.originalSubscribe = this.bus.subscribe;
      this.originalUnsubscribe = this.bus.unsubscribe;
      this.originalAjaxDescriptor = Object.getOwnPropertyDescriptor(
        this.bus,
        "ajax"
      );
      this.originalLongPollDescriptor = Object.getOwnPropertyDescriptor(
        this.bus,
        "longPoll"
      );

      this.bus.callbacks.length = 0;
      this.bus.longPoll = null;
    });

    hooks.afterEach(function () {
      uninstall();

      this.bus.callbacks.length = 0;
      this.bus.callbacks.push(...this.originalCallbacks);
      this.bus.subscribe = this.originalSubscribe;
      this.bus.unsubscribe = this.originalUnsubscribe;
      Object.defineProperty(this.bus, "ajax", this.originalAjaxDescriptor);

      if (this.originalLongPollDescriptor) {
        Object.defineProperty(
          this.bus,
          "longPoll",
          this.originalLongPollDescriptor
        );
      } else {
        delete this.bus.longPoll;
      }
    });

    test("subscribe returns the caller's function while registering a distinct wrapper", function (assert) {
      const handler = () => {};

      install();

      assert.strictEqual(
        this.bus.subscribe("/identity", handler, 41),
        handler,
        "the public return value keeps the library contract"
      );
      assert.notStrictEqual(
        this.bus.callbacks[0].func,
        handler,
        "the live callback entry is instrumented"
      );
      assert.strictEqual(
        this.bus.callbacks[0].last_id,
        41,
        "the requested last id reaches MessageBus"
      );
    });

    test("exact unsubscribe removes every duplicate for one function without disturbing its other channels", function (assert) {
      let aborts = 0;
      const sharedHandler = () => {};
      const otherHandler = () => {};

      this.bus.longPoll = { abort: () => aborts++ };
      install();
      this.bus.subscribe("/same", sharedHandler);
      this.bus.subscribe("/same", sharedHandler);
      this.bus.subscribe("/same", otherHandler);
      this.bus.subscribe("/elsewhere", sharedHandler);
      aborts = 0;

      assert.true(
        this.bus.unsubscribe("/same", sharedHandler),
        "at least one matching subscription was removed"
      );
      assert.strictEqual(aborts, 1, "the active poll is aborted once");
      assert.deepEqual(
        callbackChannels(this.bus),
        ["/same", "/elsewhere"],
        "both duplicate pairs are removed and the other channel remains"
      );

      const [sameEntry, elsewhereEntry] = this.bus.callbacks;
      this.bus.unsubscribe("/same", otherHandler);
      assert.strictEqual(
        elsewhereEntry,
        this.bus.callbacks[0],
        "removing the other handler does not remove the shared handler elsewhere"
      );
      assert.notStrictEqual(
        sameEntry,
        this.bus.callbacks[0],
        "the exact-channel match was removed"
      );
    });

    test("glob unsubscribe compares each wrapper's original function", function (assert) {
      const sharedHandler = () => {};
      const otherHandler = () => {};

      install();
      this.bus.subscribe("/private/1", sharedHandler);
      this.bus.subscribe("/private/2", sharedHandler);
      this.bus.subscribe("/private/3", otherHandler);
      this.bus.subscribe("/private-ish", sharedHandler);

      assert.true(this.bus.unsubscribe("/private/*", sharedHandler));
      assert.deepEqual(
        callbackChannels(this.bus),
        ["/private/3", "/private-ish"],
        "only prefix matches belonging to the requested function are removed"
      );
    });

    test("omitting func removes all channel matches and a bare wildcard removes everything", function (assert) {
      install();
      this.bus.subscribe("/duplicate", () => {});
      this.bus.subscribe("/duplicate", () => {});
      this.bus.subscribe("/remaining/a", () => {});
      this.bus.subscribe("/remaining/b", () => {});

      assert.true(this.bus.unsubscribe("/duplicate"));
      assert.deepEqual(callbackChannels(this.bus), [
        "/remaining/a",
        "/remaining/b",
      ]);

      assert.true(this.bus.unsubscribe("*"));
      assert.deepEqual(
        this.bus.callbacks,
        [],
        "the empty glob prefix matches all"
      );
      assert.false(
        this.bus.unsubscribe("*"),
        "a second removal reports that nothing changed"
      );
    });

    test("subscriptions present at installation remain removable by their original function", function (assert) {
      const handler = () => {};
      const kept = { channel: "/before/keep", func: handler, last_id: 8 };
      const removed = { channel: "/before/remove", func: handler, last_id: 13 };

      this.bus.callbacks.push(kept, removed);
      install();

      assert.notStrictEqual(
        kept.func,
        handler,
        "the existing entry is wrapped"
      );
      assert.notStrictEqual(
        removed.func,
        handler,
        "each entry has its own wrapper"
      );
      assert.notStrictEqual(
        kept.func,
        removed.func,
        "one original function can have multiple wrappers"
      );
      assert.true(this.bus.unsubscribe("/before/remove", handler));

      uninstall();

      assert.deepEqual(callbackChannels(this.bus), ["/before/keep"]);
      assert.strictEqual(
        kept.func,
        handler,
        "a surviving pre-install entry is restored in place"
      );
      assert.strictEqual(
        kept.last_id,
        8,
        "unrelated callback state is preserved"
      );
    });

    test("subscriber wrappers preserve receiver, arguments, and return identity", function (assert) {
      const receiver = { name: "receiver" };
      const returnedPromise = Promise.resolve("finished");
      let observedReceiver;
      let observedArguments;

      function handler(...args) {
        observedReceiver = this;
        observedArguments = args;
        return returnedPromise;
      }

      install();
      this.bus.subscribe("/transparent", handler);

      const returned = this.bus.callbacks[0].func.call(receiver, "payload", 7);

      assert.strictEqual(observedReceiver, receiver);
      assert.deepEqual(observedArguments, ["payload", 7]);
      assert.strictEqual(returned, returnedPromise);
      assert.strictEqual(subscriptions()[0].calls, 1);
    });

    test("subscriber wrappers rethrow the identical exception", function (assert) {
      const failure = new Error("subscriber failed");
      let caught;

      install();
      this.bus.subscribe("/failure", () => {
        throw failure;
      });

      try {
        this.bus.callbacks[0].func();
      } catch (error) {
        caught = error;
      }

      assert.strictEqual(
        caught,
        failure,
        "the original exception escapes unchanged"
      );
      assert.strictEqual(subscriptions()[0].errors, 1);
      assert.strictEqual(subscriptions()[0].lastError, "subscriber failed");
    });

    test("ajax assignments made before and after install both become the active adapter", function (assert) {
      const firstResult = {};
      const secondResult = {};
      const firstOptions = { request: 1 };
      const secondOptions = { request: 2 };
      let firstReceived;
      let secondReceived;
      const firstAdapter = (options) => {
        firstReceived = options;
        return firstResult;
      };
      const secondAdapter = (options) => {
        secondReceived = options;
        return secondResult;
      };

      this.bus.ajax = firstAdapter;
      install();

      assert.strictEqual(this.bus.ajax(firstOptions), firstResult);
      assert.strictEqual(firstReceived, firstOptions);

      this.bus.ajax = secondAdapter;

      assert.notStrictEqual(
        this.bus.ajax,
        secondAdapter,
        "the instrumentation remains outermost after replacement"
      );
      assert.strictEqual(this.bus.ajax(secondOptions), secondResult);
      assert.strictEqual(secondReceived, secondOptions);
      assert.strictEqual(messageBusState().polls, 2);

      uninstall();

      const descriptor = Object.getOwnPropertyDescriptor(this.bus, "ajax");
      assert.strictEqual(descriptor.value, secondAdapter);
      assert.true(descriptor.writable, "ajax is restored as writable data");
      assert.strictEqual(descriptor.get, undefined, "the accessor is removed");
      assert.strictEqual(messageBusState().polls, 0, "observations are reset");
    });

    test("ajax instrumentation preserves the adapter receiver", function (assert) {
      let adapterReceiver;

      this.bus.ajax = function () {
        adapterReceiver = this;
      };
      install();

      this.bus.ajax({ request: "receiver-check" });

      assert.strictEqual(
        adapterReceiver,
        this.bus,
        "the adapter is still invoked as a method of MessageBus"
      );
    });

    test("a missing ajax adapter keeps MessageBus's public error", function (assert) {
      this.bus.ajax = undefined;
      install();

      assert.throws(
        () => this.bus.ajax({}),
        /Either jQuery or the ajax adapter must be loaded/
      );

      uninstall();

      const descriptor = Object.getOwnPropertyDescriptor(this.bus, "ajax");
      assert.strictEqual(descriptor.value, undefined);
      assert.true(descriptor.writable);
    });

    test("chunked xhr decoration preserves the factory receiver and observes progress frames", function (assert) {
      const separator = "\r\n|\r\n";
      const xhr = {
        responseText: "",
        onprogress: null,
        addEventListener(type, listener) {
          assert.strictEqual(type, "progress");
          this.instrumentationProgress = listener;
        },
      };
      const messageBusOptions = {
        chunked: true,
        onProgressListener(candidate) {
          candidate.onprogress = () => {};
        },
      };
      let adapterOptions;
      let xhrFactoryReceiver;

      this.bus.ajax = (options) => {
        adapterOptions = options;
        return options.xhr();
      };
      install();

      const returnedXhr = this.bus.ajax({
        messageBus: messageBusOptions,
        xhr() {
          xhrFactoryReceiver = this;
          this.messageBus.onProgressListener(xhr);
          return xhr;
        },
      });

      assert.strictEqual(returnedXhr, xhr);
      assert.strictEqual(
        xhrFactoryReceiver,
        adapterOptions,
        "the original factory receives the object used for method invocation"
      );
      assert.strictEqual(xhrFactoryReceiver.messageBus, messageBusOptions);
      assert.strictEqual(typeof xhr.onprogress, "function");
      assert.strictEqual(typeof xhr.instrumentationProgress, "function");

      xhr.responseText =
        JSON.stringify([
          {
            channel: "/first",
            data: { value: 1 },
            global_id: 101,
            message_id: 11,
          },
        ]) + separator;
      xhr.instrumentationProgress();

      xhr.responseText += JSON.stringify([
        {
          channel: "/second",
          data: { value: 2 },
          global_id: 102,
          message_id: 12,
        },
      ]);
      xhr.instrumentationProgress();
      assert.strictEqual(
        messageBusState().messages.length,
        1,
        "an incomplete frame is held back"
      );

      xhr.responseText += separator;
      xhr.instrumentationProgress();

      assert.deepEqual(
        messageBusState().messages.map(
          ({ channel, data, globalId, messageId }) => ({
            channel,
            data,
            globalId,
            messageId,
          })
        ),
        [
          {
            channel: "/first",
            data: { value: 1 },
            globalId: 101,
            messageId: 11,
          },
          {
            channel: "/second",
            data: { value: 2 },
            globalId: 102,
            messageId: 12,
          },
        ],
        "each completed frame is observed exactly once"
      );
    });

    test("install and uninstall are idempotent and restore all replaced surfaces", function (assert) {
      const originalSubscribe = this.bus.subscribe;
      const originalUnsubscribe = this.bus.unsubscribe;
      const originalAjax = this.bus.ajax;
      const handler = () => {};

      this.bus.callbacks.push({
        channel: "/existing",
        func: handler,
        last_id: -2,
      });

      install();
      const installedSubscribe = this.bus.subscribe;
      const installedUnsubscribe = this.bus.unsubscribe;
      const installedAjax = this.bus.ajax;
      const installedCallback = this.bus.callbacks[0].func;

      install();

      assert.strictEqual(this.bus.subscribe, installedSubscribe);
      assert.strictEqual(this.bus.unsubscribe, installedUnsubscribe);
      assert.strictEqual(this.bus.ajax, installedAjax);
      assert.strictEqual(this.bus.callbacks[0].func, installedCallback);
      assert.true(messageBusState().installed);

      uninstall();
      uninstall();

      assert.strictEqual(this.bus.subscribe, originalSubscribe);
      assert.strictEqual(this.bus.unsubscribe, originalUnsubscribe);
      assert.strictEqual(this.bus.ajax, originalAjax);
      assert.strictEqual(this.bus.callbacks[0].func, handler);
      assert.false(messageBusState().installed);
      assert.deepEqual(messageBusState().messages, []);
    });
  }
);
