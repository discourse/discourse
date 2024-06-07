import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import sinon from "sinon";
import { withPluginApi } from "discourse/lib/plugin-api";
import {
  acceptNewTransformerNames,
  acceptTransformerRegistrations,
  applyTransformer,
  transformerExists,
} from "discourse/lib/plugin-api/value-transformer";

module("Unit | Utility | transformers", function (hooks) {
  setupTest(hooks);

  module("pluginApi.addTransformerName", function (innerHooks) {
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
          withPluginApi("1.33.0", (api) => {
            api.addTransformerName("whatever");
          }),
        /was called when the system is no longer accepting new names to be added/
      );
    });

    test("warns if name is already registered", function (assert) {
      acceptNewTransformerNames();

      withPluginApi("1.33.0", (api) => {
        api.addTransformerName("home-logo-href"); // existing core transformer

        // testing warning about core transformers
        assert.strictEqual(
          this.consoleWarnStub.calledWith(
            sinon.match(/matches an existing core transformer/)
          ),
          true,
          "logs warning to the console about existing core transformer with the same name"
        );

        // testing warning about plugin transformers
        this.consoleWarnStub.reset();

        api.addTransformerName("new-plugin-transformer"); // first time should go through
        assert.strictEqual(
          this.consoleWarnStub.notCalled,
          true,
          "did not log warning to the console"
        );

        api.addTransformerName("new-plugin-transformer"); // second time log a warning

        assert.strictEqual(
          this.consoleWarnStub.calledWith(sinon.match(/is already registered/)),
          true,
          "logs warning to the console about transformer already added with the same name"
        );
      });
    });

    test("adds a new transformer name", function (assert) {
      acceptNewTransformerNames();

      withPluginApi("1.33.0", (api) => {
        assert.strictEqual(
          transformerExists("a-new-plugin-transformer"),
          false,
          "initially the transformer does not exists"
        );
        api.addTransformerName("a-new-plugin-transformer"); // second time log a warning
        assert.strictEqual(
          transformerExists("a-new-plugin-transformer"),
          true,
          "the new transformer was added"
        );
      });
    });
  });

  module("pluginApi.registerTransformer", function (innerHooks) {
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
          withPluginApi("1.33.0", (api) => {
            api.registerTransformer("whatever", () => "foo"); // the name doesn't really matter at this point
          }),
        /was called while the system was still accepting new transformer names/
      );
    });

    test("warns if transformer is unknown", function (assert) {
      withPluginApi("1.33.0", (api) => {
        api.registerTransformer("whatever", () => "foo");

        // testing warning about core transformers
        assert.strictEqual(
          this.consoleWarnStub.calledWith(
            sinon.match(/is unknown and will be ignored/)
          ),
          true
        );
      });
    });

    test("raises an exception if the callback parameter is not a function", function (assert) {
      assert.throws(
        () =>
          withPluginApi("1.33.0", (api) => {
            api.registerTransformer("whatever", "foo");
          }),
        /requires the valueCallback argument to be a function/
      );
    });

    test("registering a new transformer works", function (assert) {
      acceptNewTransformerNames();

      withPluginApi("1.33.0", (api) => {
        api.addTransformerName("test-transformer");
        acceptTransformerRegistrations();

        const transformerWasRegistered = (name) =>
          applyTransformer(name, false);

        assert.strictEqual(
          transformerWasRegistered("test-transformer"),
          false,
          "value did not change. transformer is not registered yet"
        );

        api.registerTransformer("test-transformer", () => true);

        assert.strictEqual(
          transformerWasRegistered("test-transformer"),
          true,
          "the transformer was registered successfully. the value did change."
        );
      });
    });
  });

  module("applyTransformer", function (innerHooks) {
    innerHooks.beforeEach(function () {
      acceptNewTransformerNames();

      withPluginApi("1.33.0", (api) => {
        api.addTransformerName("test-value1-transformer");
        api.addTransformerName("test-value2-transformer");
      });

      acceptTransformerRegistrations();
    });

    test("raises an exception if the transformer name does not exist", function (assert) {
      assert.throws(
        () => applyTransformer("whatever", "foo"),
        /does not exist. Did you forget to register it/
      );
    });

    test("applying the transformer works", function (assert) {
      class Testable {
        #value;

        constructor(value) {
          this.#value = value;
        }

        get value1() {
          return applyTransformer("test-value1-transformer", this.#value);
        }

        get value2() {
          return applyTransformer("test-value2-transformer", this.#value);
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
        "it returns the default values when there are no transformers registered"
      );

      withPluginApi("1.33.0", (api) => {
        api.registerTransformer("test-value1-transformer", ({ value }) => {
          return value * 10;
        });
      });

      assert.deepEqual(
        [testObject1.value1, testObject2.value1],
        [10, 20],
        "when a transformer was registered, it returns the transformed value"
      );

      assert.deepEqual(
        [testObject1.value2, testObject2.value2],
        [1, 2],
        "transformer names without transformers registered are not affected"
      );
    });

    test("the transformer callback can receive an optional context object", function (assert) {
      let expectedContext = null;

      withPluginApi("1.33.0", (api) => {
        api.registerTransformer(
          "test-value1-transformer",
          // eslint-disable-next-line no-unused-vars
          ({ value, context }) => {
            expectedContext = context; // this function should be pure, but we're using side effects just for the test

            return true;
          }
        );
      });

      const value = applyTransformer("test-value1-transformer", false, {
        prop1: true,
        prop2: false,
      });

      assert.strictEqual(value, true, "the value was transformed");
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
          return applyTransformer("test-value1-transformer", ["r"]);
        }
      }

      const testObject = new Testable();

      assert.deepEqual(
        testObject.sequence,
        ["r"],
        `initially the sequence contains only the element "r"`
      );

      withPluginApi("1.33.0", (api) => {
        api.registerTransformer("test-value1-transformer", ({ value }) => {
          return ["r", ...value];
        });
        api.registerTransformer("test-value1-transformer", ({ value }) => {
          return [...value, "e", "c"];
        });
        api.registerTransformer("test-value1-transformer", ({ value }) => {
          return ["o", ...value];
        });
        api.registerTransformer("test-value1-transformer", ({ value }) => {
          return ["c", ...value, "t"];
        });
      });

      assert.strictEqual(
        testObject.sequence.join(""),
        "correct",
        `the transformers applied in the expected sequence will produce the word "correct"`
      );
    });
  });
});
