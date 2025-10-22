import EmberObject from "@ember/object";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import sinon from "sinon";
import { withPluginApi } from "discourse/lib/plugin-api";
import {
  acceptNewTransformerNames,
  acceptTransformerRegistrations,
  applyBehaviorTransformer,
  applyMutableValueTransformer,
  applyValueTransformer,
  disableThrowingApplyExceptionOnTests,
  transformerTypes,
  transformerWasAdded,
} from "discourse/lib/transformer";

function notThrows(testCallback) {
  try {
    testCallback();
    return true;
  } catch {
    return false;
  }
}

module("Unit | Utility | transformers", function (hooks) {
  setupTest(hooks);

  module("pluginApi.addValueTransformerName", function (innerHooks) {
    innerHooks.beforeEach(function () {
      this.consoleWarnStub = sinon.stub(console, "warn");
    });

    innerHooks.afterEach(function () {
      this.consoleWarnStub.restore();
    });

    test("raises an exception if the system is already accepting transformers to registered", function (assert) {
      // there is no need to freeze the list of valid transformers because that happen when the test application is
      // initialized in `setupTest`

      assert.throws(
        () =>
          withPluginApi((api) => {
            api.addValueTransformerName("whatever");
          }),
        /addValueTransformerName was called when the system is no longer accepting new names to be added/
      );
    });

    test("warns if name is already registered", function (assert) {
      acceptNewTransformerNames();

      withPluginApi((api) => {
        api.addValueTransformerName("home-logo-href"); // existing core transformer

        // testing warning about core transformers
        assert.true(
          this.consoleWarnStub.calledWith(
            sinon.match(/matches existing core transformer/)
          ),
          "logs warning to the console about existing core transformer with the same name"
        );

        // testing warning about plugin transformers
        this.consoleWarnStub.reset();

        api.addValueTransformerName("new-plugin-transformer"); // first time should go through
        assert.true(
          this.consoleWarnStub.notCalled,
          "did not log warning to the console"
        );

        api.addValueTransformerName("new-plugin-transformer"); // second time log a warning

        assert.true(
          this.consoleWarnStub.calledWith(sinon.match(/is already registered/)),
          "logs warning to the console about transformer already added with the same name"
        );
      });
    });

    test("adds a new transformer name", function (assert) {
      acceptNewTransformerNames();

      withPluginApi((api) => {
        assert.false(
          transformerWasAdded(
            "a-new-plugin-transformer",
            transformerTypes.VALUE
          ),
          "initially the transformer does not exists"
        );
        api.addValueTransformerName("a-new-plugin-transformer"); // second time log a warning
        assert.true(
          transformerWasAdded(
            "a-new-plugin-transformer",
            transformerTypes.VALUE
          ),
          "the new transformer is added"
        );
      });
    });
  });

  module("pluginApi.registerValueTransformer", function (innerHooks) {
    innerHooks.beforeEach(function () {
      this.consoleWarnStub = sinon.stub(console, "warn");
    });

    innerHooks.afterEach(function () {
      this.consoleWarnStub.restore();
    });

    test("raises an exception if the application the system is still waiting for transformer names to be registered", function (assert) {
      acceptNewTransformerNames();

      assert.throws(
        () =>
          withPluginApi((api) => {
            api.registerValueTransformer("whatever", () => "foo"); // the name doesn't really matter at this point
          }),
        /was called while the system was still accepting new transformer names/
      );
    });

    test("warns if transformer is unknown", function (assert) {
      withPluginApi((api) => {
        const result = api.registerValueTransformer("whatever", () => "foo");
        assert.false(
          result,
          "registerValueTransformer returns false if the transformer name does not exist"
        );

        // testing warning about core transformers
        assert.true(
          this.consoleWarnStub.calledWith(
            sinon.match(/is unknown and will be ignored/)
          )
        );
      });
    });

    test("raises an exception if the callback parameter is not a function", function (assert) {
      assert.throws(
        () =>
          withPluginApi((api) => {
            api.registerValueTransformer("home-logo-href", "foo");
          }),
        /api.registerValueTransformer requires the callback argument to be a function/
      );
    });

    test("registering a new transformer works", function (assert) {
      acceptNewTransformerNames();

      withPluginApi((api) => {
        api.addValueTransformerName("test-transformer");
        acceptTransformerRegistrations();

        const transformerWasRegistered = (name) =>
          applyValueTransformer(name, false);

        assert.false(
          transformerWasRegistered("test-transformer"),
          "value did not change. transformer is not registered yet"
        );

        const result = api.registerValueTransformer(
          "test-transformer",
          () => true
        );
        assert.true(
          result,
          "registerValueTransformer returns true if the transformer is registered"
        );

        assert.true(
          transformerWasRegistered("test-transformer"),
          "the transformer is registered successfully, the value did change"
        );
      });
    });
  });

  module("applyValueTransformer", function (innerHooks) {
    innerHooks.beforeEach(function () {
      this.documentDispatchEventStub = sinon.stub(document, "dispatchEvent");

      acceptNewTransformerNames();

      withPluginApi((api) => {
        api.addValueTransformerName("test-value1-transformer");
        api.addValueTransformerName("test-value2-transformer");
      });

      acceptTransformerRegistrations();
    });

    innerHooks.afterEach(function () {
      this.documentDispatchEventStub.restore();
    });

    test("raises an exception if the transformer name does not exist", function (assert) {
      assert.throws(
        () => applyValueTransformer("whatever", "foo"),
        /does not exist./
      );
    });

    test("accepts only simple objects as context", function (assert) {
      assert.true(
        notThrows(() =>
          applyValueTransformer("test-value1-transformer", "foo")
        ),
        "doesn't throw an error if context is not passed"
      );

      assert.true(
        notThrows(() =>
          applyValueTransformer("test-value1-transformer", "foo", undefined)
        ),
        "doesn't throw an error if context is undefined"
      );

      assert.true(
        notThrows(() =>
          applyValueTransformer("test-value1-transformer", "foo", null)
        ),
        "doesn't throw an error if context is null"
      );

      assert.true(
        notThrows(() =>
          applyValueTransformer("test-value1-transformer", "foo", {
            pojo: true,
            property: "foo",
          })
        ),
        "doesn't throw an error if context is a POJO"
      );

      assert.throws(
        () => applyValueTransformer("test-value1-transformer", "foo", ""),
        /context must be a simple JS object/,
        "throws an error if context is a string"
      );

      assert.throws(
        () => applyValueTransformer("test-value1-transformer", "foo", 0),
        /context must be a simple JS object/,
        "throws an error if context is a number"
      );

      assert.throws(
        () => applyValueTransformer("test-value1-transformer", "foo", false),
        /context must be a simple JS object/,
        "throws an error if context is a boolean value"
      );

      assert.throws(
        () =>
          applyValueTransformer(
            "test-value1-transformer",
            "foo",
            () => "function"
          ),
        /context must be a simple JS object/,
        "throws an error if context is a function"
      );

      assert.throws(
        () =>
          applyValueTransformer(
            "test-value1-transformer",
            "foo",
            EmberObject.create({
              test: true,
            })
          ),
        /context must be a simple JS object/,
        "throws an error if context is an Ember object"
      );

      assert.throws(
        () =>
          applyValueTransformer(
            "test-value1-transformer",
            "foo",
            EmberObject.create({
              test: true,
            })
          ),
        /context must be a simple JS object/,
        "throws an error if context is an Ember component"
      );

      class Testable {}

      assert.throws(
        () =>
          applyValueTransformer(
            "test-value1-transformer",
            "foo",
            new Testable()
          ),
        /context must be a simple JS object/,
        "throws an error if context is an instance of a class"
      );
    });

    test("accepts an ember hash proxy as context", function (assert) {
      // A hash-like object
      const hash = { a: 1 };
      Object.setPrototypeOf(hash, null);
      const proxy = new Proxy(hash, {});

      assert.true(
        notThrows(() =>
          applyValueTransformer("test-value1-transformer", "foo", proxy)
        ),
        "doesn't throw an error if context is a proxy to an ember hash object"
      );
    });

    test("applying the transformer works", function (assert) {
      class Testable {
        #value;

        constructor(value) {
          this.#value = value;
        }

        get value1() {
          return applyValueTransformer("test-value1-transformer", this.#value);
        }

        get value2() {
          return applyValueTransformer("test-value2-transformer", this.#value);
        }
      }

      const testObject1 = new Testable(1);
      const testObject2 = new Testable(2);

      assert.deepEqual(
        [
          testObject1.value1,
          testObject1.value2,
          testObject2.value1,
          testObject2.value2,
        ],
        [1, 1, 2, 2],
        "returns the default values when there are no transformers registered"
      );

      withPluginApi((api) => {
        api.registerValueTransformer("test-value1-transformer", ({ value }) => {
          return value * 10;
        });
      });

      assert.deepEqual(
        [testObject1.value1, testObject2.value1],
        [10, 20],
        "when a transformer is registered, it returns the transformed value"
      );

      assert.deepEqual(
        [testObject1.value2, testObject2.value2],
        [1, 2],
        "transformer names without transformers registered are not affected"
      );
    });

    test("exceptions are handled when applying the transformer", function (assert) {
      class Testable {
        #value;

        constructor(value) {
          this.#value = value;
        }

        get value1() {
          return applyValueTransformer("test-value1-transformer", this.#value);
        }

        get value2() {
          return applyValueTransformer("test-value2-transformer", this.#value);
        }
      }

      const testObject1 = new Testable(1);
      const testObject2 = new Testable(2);

      withPluginApi((api) => {
        api.registerValueTransformer("test-value1-transformer", () => {
          throw new Error("sabotaged");
        });
      });

      assert.throws(
        function () {
          testObject1.value1;
        },
        function (error) {
          return error.message === "sabotaged";
        },
        "by default throws an exception on tests when the transformer registered has an error"
      );

      disableThrowingApplyExceptionOnTests();
      assert.deepEqual(
        [testObject1.value1, testObject2.value1],
        [1, 2],
        "catches the exception and returns the default value when the only transformer registered has an error"
      );

      assert.true(
        this.documentDispatchEventStub.calledWith(
          sinon.match
            .instanceOf(CustomEvent)
            .and(sinon.match.has("type", "discourse-error"))
            .and(
              sinon.match.has(
                "detail",
                sinon.match({
                  messageKey: "broken_transformer_alert",
                  error: sinon.match
                    .instanceOf(Error)
                    .and(sinon.match.has("message", "sabotaged")),
                })
              )
            )
        ),
        "dispatches an event to display a message do admins when an exception is caught in a transformer"
      );

      withPluginApi((api) => {
        api.registerValueTransformer("test-value1-transformer", () => {
          return 0;
        });
      });

      assert.deepEqual(
        [testObject1.value1, testObject2.value1],
        [0, 0],
        "catches the exception and keeps processing the queue when there are others transformers registered"
      );
    });

    test("the transformer callback can receive an optional context object", function (assert) {
      let expectedContext = null;

      withPluginApi((api) => {
        api.registerValueTransformer(
          "test-value1-transformer",
          // eslint-disable-next-line no-unused-vars
          ({ value, context }) => {
            expectedContext = context; // this function should be pure, but we're using side effects just for the test

            return true;
          }
        );
      });

      const value = applyValueTransformer("test-value1-transformer", false, {
        prop1: true,
        prop2: false,
      });

      assert.true(value, "the value is transformed");
      assert.deepEqual(
        expectedContext,
        {
          prop1: true,
          prop2: false,
        },
        "the callback received the expected context"
      );
    });

    test("multiple transformers registered for the same name will be applied in sequence", function (assert) {
      class Testable {
        get sequence() {
          return applyValueTransformer("test-value1-transformer", ["r"]);
        }
      }

      const testObject = new Testable();

      assert.deepEqual(
        testObject.sequence,
        ["r"],
        `initially the sequence contains only the element "r"`
      );

      withPluginApi((api) => {
        api.registerValueTransformer("test-value1-transformer", ({ value }) => {
          return ["r", ...value];
        });
        api.registerValueTransformer("test-value1-transformer", ({ value }) => {
          return [...value, "e", "c"];
        });
        api.registerValueTransformer("test-value1-transformer", ({ value }) => {
          return ["o", ...value];
        });
        api.registerValueTransformer("test-value1-transformer", ({ value }) => {
          return ["c", ...value, "t"];
        });
      });

      assert.strictEqual(
        testObject.sequence.join(""),
        "correct",
        `the transformers applied in the expected sequence produce the word "correct"`
      );
    });
  });

  module("applyMutableValueTransformer", function (innerHooks) {
    innerHooks.beforeEach(function () {
      acceptNewTransformerNames();
      withPluginApi((api) => {
        api.addValueTransformerName("test-mutable-transformer");
      });
      acceptTransformerRegistrations();
    });

    test("mutates the value as expected", function (assert) {
      withPluginApi((api) => {
        api.registerValueTransformer(
          "test-mutable-transformer",
          ({ value }) => {
            value.mutate();
          }
        );
      });

      let mutated = false;
      const value = {
        mutate() {
          mutated = true;
        },
      };

      applyMutableValueTransformer("test-mutable-transformer", value);
      assert.true(mutated, "the value is mutated");
    });
  });

  module("pluginApi.addBehaviorTransformerName", function (innerHooks) {
    innerHooks.beforeEach(function () {
      this.consoleWarnStub = sinon.stub(console, "warn");
    });

    innerHooks.afterEach(function () {
      this.consoleWarnStub.restore();
    });

    test("raises an exception if the system is already accepting transformers to registered", function (assert) {
      // there is no need to freeze the list of valid transformers because that happen when the test application is
      // initialized in `setupTest`

      assert.throws(
        () =>
          withPluginApi((api) => {
            api.addBehaviorTransformerName("whatever");
          }),
        /addBehaviorTransformerName was called when the system is no longer accepting new names to be added/
      );
    });

    test("warns if name is already registered", function (assert) {
      acceptNewTransformerNames();

      withPluginApi((api) => {
        api.addBehaviorTransformerName("home-logo-href"); // existing core transformer

        // testing warning about core transformers
        assert.true(
          this.consoleWarnStub.calledWith(
            sinon.match(/matches existing core transformer/)
          ),
          "logs warning to the console about existing core transformer with the same name"
        );

        // testing warning about plugin transformers
        this.consoleWarnStub.reset();

        api.addBehaviorTransformerName("new-plugin-transformer"); // first time should go through
        assert.true(
          this.consoleWarnStub.notCalled,
          "does not log warning to the console"
        );

        api.addBehaviorTransformerName("new-plugin-transformer"); // second time log a warning

        assert.true(
          this.consoleWarnStub.calledWith(sinon.match(/is already registered/)),
          "logs warning to the console about transformer already added with the same name"
        );
      });
    });

    test("adds a new transformer name", function (assert) {
      acceptNewTransformerNames();

      withPluginApi((api) => {
        assert.false(
          transformerWasAdded(
            "a-new-plugin-transformer",
            transformerTypes.BEHAVIOR
          ),
          "initially the transformer does not exists"
        );
        api.addBehaviorTransformerName("a-new-plugin-transformer"); // second time log a warning
        assert.true(
          transformerWasAdded(
            "a-new-plugin-transformer",
            transformerTypes.BEHAVIOR
          ),
          "the new transformer is added"
        );
      });
    });
  });

  module("pluginApi.registerBehaviorTransformer", function (innerHooks) {
    innerHooks.beforeEach(function () {
      this.consoleWarnStub = sinon.stub(console, "warn");
    });

    innerHooks.afterEach(function () {
      this.consoleWarnStub.restore();
    });

    test("raises an exception if the application the system is still waiting for transformer names to be registered", function (assert) {
      acceptNewTransformerNames();

      assert.throws(
        () =>
          withPluginApi((api) => {
            api.registerBehaviorTransformer("whatever", () => "foo"); // the name doesn't really matter at this point
          }),
        /was called while the system was still accepting new transformer names/
      );
    });

    test("warns if transformer is unknown ans returns false", function (assert) {
      withPluginApi((api) => {
        const result = api.registerBehaviorTransformer("whatever", () => "foo");
        assert.false(
          result,
          "registerBehaviorTransformer returns false if the transformer name does not exist"
        );

        // testing warning about core transformers
        assert.true(
          this.consoleWarnStub.calledWith(
            sinon.match(/is unknown and will be ignored/)
          )
        );
      });
    });

    test("raises an exception if the callback parameter is not a function", function (assert) {
      assert.throws(
        () =>
          withPluginApi((api) => {
            api.registerBehaviorTransformer(
              "discovery-topic-list-load-more",
              "foo"
            );
          }),
        /api.registerBehaviorTransformer requires the callback argument to be a function/
      );
    });

    test("registering a new transformer works", function (assert) {
      acceptNewTransformerNames();

      withPluginApi((api) => {
        api.addBehaviorTransformerName("test-transformer");
        acceptTransformerRegistrations();

        let value = null;

        const transformerWasRegistered = (name) =>
          applyBehaviorTransformer(name, () => (value = "DEFAULT_CALLBACK"), {
            setValue: (v) => (value = v),
          });

        assert.strictEqual(
          value,
          null,
          "value is null, behavior callback was not executed yet"
        );

        transformerWasRegistered("test-transformer");
        assert.strictEqual(
          value,
          "DEFAULT_CALLBACK",
          "value is set by the default callback, transformer is not registered yet"
        );

        const result = api.registerBehaviorTransformer(
          "test-transformer",
          ({ context }) => context.setValue("TRANSFORMED_CALLBACK")
        );
        assert.true(
          result,
          "registerBehaviorTransformer returns true if the transformer is registered"
        );

        transformerWasRegistered("test-transformer");
        assert.strictEqual(
          value,
          "TRANSFORMED_CALLBACK",
          "the transformer is registered successfully, the value did change"
        );
      });
    });
  });

  module("applyBehaviorTransformer", function (innerHooks) {
    innerHooks.beforeEach(function () {
      this.documentDispatchEventStub = sinon.stub(document, "dispatchEvent");

      acceptNewTransformerNames();

      withPluginApi((api) => {
        api.addBehaviorTransformerName("test-behavior1-transformer");
        api.addBehaviorTransformerName("test-behavior2-transformer");
      });

      acceptTransformerRegistrations();
    });

    innerHooks.afterEach(function () {
      this.documentDispatchEventStub.restore();
    });

    test("raises an exception if the transformer name does not exist", function (assert) {
      assert.throws(
        () => applyBehaviorTransformer("whatever", "foo"),
        /applyBehaviorTransformer: transformer name(.*)does not exist./
      );
    });

    test("raises an exception if the callback argument provided is not a function", function (assert) {
      assert.throws(
        () => applyBehaviorTransformer("test-behavior1-transformer", "foo"),
        /requires the callback argument/
      );
    });

    test("accepts only simple objects as context", function (assert) {
      assert.true(
        notThrows(() =>
          applyBehaviorTransformer("test-behavior1-transformer", () => true)
        ),
        "doesn't throw an error if context is not passed"
      );

      assert.true(
        notThrows(() =>
          applyBehaviorTransformer(
            "test-behavior1-transformer",
            () => true,
            undefined
          )
        ),
        "doesn't throw an error if context is undefined"
      );

      assert.true(
        notThrows(() =>
          applyBehaviorTransformer(
            "test-behavior1-transformer",
            () => true,
            null
          )
        ),
        "doesn't throw an error if context is null"
      );

      assert.true(
        notThrows(() =>
          applyBehaviorTransformer("test-behavior1-transformer", () => true, {
            pojo: true,
            property: "foo",
          })
        ),
        "doesn't throw an error if context is a POJO"
      );

      assert.throws(
        () =>
          applyBehaviorTransformer(
            "test-behavior1-transformer",
            () => true,
            ""
          ),
        /context must be a simple JS object/,
        "throws an error if context is a string"
      );

      assert.throws(
        () =>
          applyBehaviorTransformer("test-behavior1-transformer", () => true, 0),
        /context must be a simple JS object/,
        "throws an error if context is a number"
      );

      assert.throws(
        () =>
          applyBehaviorTransformer(
            "test-behavior1-transformer",
            () => true,
            false
          ),
        /context must be a simple JS object/,
        "throws an error if context is a boolean behavior"
      );

      assert.throws(
        () =>
          applyBehaviorTransformer(
            "test-behavior1-transformer",
            () => true,
            () => "function"
          ),
        /context must be a simple JS object/,
        "throws an error if context is a function"
      );

      assert.throws(
        () =>
          applyBehaviorTransformer(
            "test-behavior1-transformer",
            () => true,
            EmberObject.create({
              test: true,
            })
          ),
        /context must be a simple JS object/,
        "throws an error if context is an Ember object"
      );

      assert.throws(
        () =>
          applyBehaviorTransformer(
            "test-behavior1-transformer",
            () => true,
            EmberObject.create({
              test: true,
            })
          ),
        /context must be a simple JS object/,
        "throws an error if context is an Ember component"
      );

      class Testable {}

      assert.throws(
        () =>
          applyBehaviorTransformer(
            "test-behavior1-transformer",
            () => true,
            new Testable()
          ),
        /context must be a simple JS object/,
        "throws an error if context is an instance of a class"
      );
    });

    test("applying the transformer works", function (assert) {
      class Testable {
        #value;

        constructor(value) {
          this.#value = value;
        }

        get value() {
          return this.#value;
        }

        multiplyValue() {
          applyBehaviorTransformer(
            "test-behavior1-transformer",
            () => {
              this.#value *= 2;
            },
            { value: this.#value, setValue: (v) => (this.#value = v) }
          );
        }

        incValue() {
          applyBehaviorTransformer(
            "test-behavior2-transformer",
            () => {
              this.#value += 1;
            },
            { value: this.#value, setValue: (v) => (this.#value = v) }
          );
        }
      }

      const testObject1 = new Testable(1);
      testObject1.multiplyValue();

      const testObject2 = new Testable(2);
      testObject2.multiplyValue();

      assert.deepEqual(
        [testObject1.value, testObject2.value],
        [2, 4],
        "the default behavior doubles the value"
      );

      withPluginApi((api) => {
        api.registerBehaviorTransformer(
          "test-behavior1-transformer",
          ({ context }) => {
            context.setValue(context.value * 10);
          }
        );
      });

      testObject1.multiplyValue();
      testObject2.multiplyValue();

      assert.deepEqual(
        [testObject1.value, testObject2.value],
        [20, 40],
        "when a transformer is registered, the method now performs transformed behavior"
      );

      testObject1.incValue();
      testObject2.incValue();

      assert.deepEqual(
        [testObject1.value, testObject2.value],
        [21, 41],
        "transformer names without transformers registered are not affected"
      );
    });

    test("applying the transformer works with Promises", async function (assert) {
      function delayedValue(value) {
        return new Promise((resolve) => {
          setTimeout(() => {
            resolve(value);
          }, 50);
        });
      }

      class Testable {
        #value = null;

        get value() {
          return this.#value;
        }

        clearValue() {
          this.#value = null;
        }

        #asyncFetchValue() {
          return delayedValue("slow foo");
        }

        initializeValue() {
          return applyBehaviorTransformer(
            "test-behavior1-transformer",
            () => {
              return this.#asyncFetchValue().then((v) => (this.#value = v));
            },
            {
              getValue: () => this.#value,
              setValue: (v) => (this.#value = v),
            }
          );
        }
      }

      const testObject = new Testable();
      assert.strictEqual(testObject.value, null, "initially the value is null");

      withPluginApi((api) => {
        api.registerBehaviorTransformer(
          "test-behavior1-transformer",
          ({ context, next }) => {
            return next()
              .then(() => delayedValue(" was too late"))
              .then((otherValue) =>
                context.setValue(context.getValue() + otherValue)
              );
          }
        );
      });

      const done = assert.async();
      testObject.initializeValue().then(() => {
        assert.strictEqual(
          testObject.value,
          "slow foo was too late",
          "the value is changed after the async behavior"
        );
        done();
      });
    });

    test("applying the transformer works with async/await behavior", async function (assert) {
      async function delayedValue(value) {
        return await new Promise((resolve) => {
          setTimeout(() => {
            resolve(value);
          }, 50);
        });
      }

      class Testable {
        #value = null;

        get value() {
          return this.#value;
        }

        clearValue() {
          this.#value = null;
        }

        async #asyncFetchValue() {
          return await delayedValue("slow foo");
        }

        async initializeValue() {
          await applyBehaviorTransformer(
            "test-behavior1-transformer",
            async () => {
              this.#value = await this.#asyncFetchValue();
            },
            {
              getValue: () => this.#value,
              setValue: (v) => (this.#value = v),
            }
          );
        }
      }

      const testObject = new Testable();
      assert.strictEqual(testObject.value, null, "initially the value is null");

      await testObject.initializeValue();
      assert.strictEqual(
        testObject.value,
        "slow foo",
        "the value is changed after the async behavior"
      );

      withPluginApi((api) => {
        api.registerBehaviorTransformer(
          "test-behavior1-transformer",
          async ({ context, next }) => {
            await next();
            const otherValue = await delayedValue(" was too late");

            context.setValue(context.getValue() + otherValue);
          }
        );
      });

      testObject.clearValue();
      await testObject.initializeValue();
      assert.strictEqual(
        testObject.value,
        "slow foo was too late",
        "when a transformer is registered, the method now performs transformed behavior"
      );
    });

    test("exceptions are handled when applying the transformer", function (assert) {
      class Testable {
        #value;

        constructor(value) {
          this.#value = value;
        }

        get value() {
          return this.#value;
        }

        multiplyValue() {
          applyBehaviorTransformer(
            "test-behavior1-transformer",
            () => {
              this.#value *= 2;
            },
            { value: this.#value, setValue: (v) => (this.#value = v) }
          );
        }

        incValue() {
          applyBehaviorTransformer(
            "test-behavior2-transformer",
            () => {
              this.#value += 1;
            },
            { value: this.#value, setValue: (v) => (this.#value = v) }
          );
        }
      }

      const testObject1 = new Testable(1);
      const testObject2 = new Testable(2);

      withPluginApi((api) => {
        api.registerBehaviorTransformer("test-behavior1-transformer", () => {
          throw new Error("sabotaged");
        });
      });

      assert.throws(
        function () {
          testObject1.multiplyValue();
        },
        function (error) {
          return error.message === "sabotaged";
        },
        "by default throws an exception on tests when the transformer registered has an error"
      );

      disableThrowingApplyExceptionOnTests();

      testObject1.multiplyValue();
      testObject2.multiplyValue();

      assert.deepEqual(
        [testObject1.value, testObject2.value],
        [2, 4],
        "catches the exception and follows the default behavior when the only transformer registered has an error"
      );

      assert.true(
        this.documentDispatchEventStub.calledWith(
          sinon.match
            .instanceOf(CustomEvent)
            .and(sinon.match.has("type", "discourse-error"))
            .and(
              sinon.match.has(
                "detail",
                sinon.match({
                  messageKey: "broken_transformer_alert",
                  error: sinon.match
                    .instanceOf(Error)
                    .and(sinon.match.has("message", "sabotaged")),
                })
              )
            )
        ),
        "dispatches an event to display a message do admins when an exception is caught in a transformer"
      );

      withPluginApi((api) => {
        api.registerBehaviorTransformer(
          "test-behavior1-transformer",
          ({ context }) => {
            context.setValue(0);
          }
        );
      });

      testObject1.multiplyValue();
      testObject2.multiplyValue();

      assert.deepEqual(
        [testObject1.value, testObject2.value],
        [0, 0],
        "catches the exception and keeps processing the queue when there are others transformers registered"
      );
    });

    test("the transformer callback can receive an optional context object", function (assert) {
      let behavior = null;
      let expectedContext = null;

      withPluginApi((api) => {
        api.registerBehaviorTransformer(
          "test-behavior1-transformer",
          ({ context }) => {
            behavior = "ALTERED";
            expectedContext = context;

            return true;
          }
        );
      });

      applyBehaviorTransformer(
        "test-behavior1-transformer",
        () => (behavior = "DEFAULT"),
        {
          prop1: true,
          prop2: false,
        }
      );

      assert.strictEqual(behavior, "ALTERED", "the behavior is transformed");
      assert.deepEqual(
        expectedContext,
        {
          prop1: true,
          prop2: false,
        },
        "the callback received the expected context"
      );
    });

    test("the transformers can call next to keep moving through the callback queue", function (assert) {
      class Testable {
        #value = [];

        resetValue() {
          this.#value = [];
        }

        buildValue() {
          return applyBehaviorTransformer(
            "test-behavior1-transformer",
            () => this.#value.push("!"),
            { pushValue: (v) => this.#value.push(v) }
          );
        }

        get value() {
          return this.#value.join("");
        }
      }

      const testObject = new Testable();
      testObject.buildValue();

      assert.strictEqual(
        testObject.value,
        "!",
        `initially buildValue value only generates "!"`
      );

      withPluginApi((api) => {
        api.registerBehaviorTransformer(
          "test-behavior1-transformer",
          ({ context, next }) => {
            context.pushValue("co");
            next();
          }
        );
        api.registerBehaviorTransformer(
          "test-behavior1-transformer",
          ({ context, next }) => {
            context.pushValue("rr");
            next();
          }
        );
        api.registerBehaviorTransformer(
          "test-behavior1-transformer",
          ({ context, next }) => {
            context.pushValue("ect");
            next();
          }
        );
      });

      testObject.resetValue();
      testObject.buildValue();

      assert.strictEqual(
        testObject.value,
        "correct!",
        `the transformers applied in the sequence produce the word "correct!"`
      );
    });

    test("when a transformer does not call next() the next transformers in the queue are not processed", function (assert) {
      class Testable {
        #value = [];

        resetValue() {
          this.#value = [];
        }

        buildValue() {
          return applyBehaviorTransformer(
            "test-behavior1-transformer",
            () => this.#value.push("!"),
            { pushValue: (v) => this.#value.push(v) }
          );
        }

        get value() {
          return this.#value.join("");
        }
      }

      const testObject = new Testable();
      testObject.buildValue();

      assert.strictEqual(
        testObject.value,
        "!",
        `initially buildValue value only generates "!"`
      );

      withPluginApi((api) => {
        api.registerBehaviorTransformer(
          "test-behavior1-transformer",
          ({ context }) => {
            context.pushValue("stopped");
          }
        );

        // the transformer below won't be called because next() is not called in the callback of the transformer above
        api.registerBehaviorTransformer(
          "test-behavior1-transformer",
          ({ context, next }) => {
            context.pushValue(" at the end");
            next();
          }
        );
      });

      testObject.resetValue();
      testObject.buildValue();

      assert.strictEqual(
        testObject.value,
        "stopped",
        // if the sequence had been executed completely, it would have produced "stopped at the end!"
        `the transformers applied in the sequence will only produce the word "stopped"`
      );
    });

    test("calling next() before the transformed behavior changes the order the queue is executed", function (assert) {
      class Testable {
        #value = [];

        resetValue() {
          this.#value = [];
        }

        buildValue() {
          return applyBehaviorTransformer(
            "test-behavior1-transformer",
            () => this.#value.push("!"),
            { pushValue: (v) => this.#value.push(v) }
          );
        }

        get value() {
          return this.#value.join(" ");
        }
      }

      const testObject = new Testable();
      testObject.buildValue();

      assert.strictEqual(
        testObject.value,
        "!",
        `initially buildValue value only generates "!"`
      );

      withPluginApi((api) => {
        api.registerBehaviorTransformer(
          "test-behavior1-transformer",
          ({ context, next }) => {
            next();
            context.pushValue("reverted");
          }
        );
        api.registerBehaviorTransformer(
          "test-behavior1-transformer",
          ({ context, next }) => {
            next();
            context.pushValue("is");
          }
        );
        api.registerBehaviorTransformer(
          "test-behavior1-transformer",
          ({ context }) => {
            context.pushValue("order");
          }
        );
      });

      testObject.resetValue();
      testObject.buildValue();

      assert.strictEqual(
        testObject.value,
        "order is reverted",
        `the transformers applied in the sequence produce the expression "order was reverted"`
      );
    });

    test("if `this` is set when applying the behavior transformer it is passed in the context as _unstable_self", function (assert) {
      class Testable {
        #value = [];

        resetValue() {
          this.#value = [];
        }

        buildValue() {
          return applyBehaviorTransformer.call(
            this,
            "test-behavior1-transformer",
            () => this.#value.push("!")
          );
        }

        get value() {
          return this.#value.join(" ");
        }

        pushValue(v) {
          this.#value.push(v);
        }
      }

      const testObject = new Testable();
      testObject.buildValue();

      assert.strictEqual(
        testObject.value,
        "!",
        `initially buildValue value only generates "!"`
      );

      withPluginApi((api) => {
        api.registerBehaviorTransformer(
          "test-behavior1-transformer",
          ({ next, context }) => {
            context._unstable_self.pushValue("added");
            next();
          }
        );

        api.registerBehaviorTransformer(
          "test-behavior1-transformer",
          ({ next, context: { _unstable_self } }) => {
            _unstable_self.pushValue("other");
            next();
          }
        );

        api.registerBehaviorTransformer(
          "test-behavior1-transformer",
          ({ context: { _unstable_self } }) => {
            _unstable_self.pushValue("items");
          }
        );
      });

      testObject.resetValue();
      testObject.buildValue();

      assert.strictEqual(
        testObject.value,
        "added other items",
        `the transformers used _unstable_self to access the component instance that called applyBehaviorTransformer`
      );
    });
  });
});
