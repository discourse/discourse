import { settled } from "@ember/test-helpers";
import { module, test } from "qunit";
import DButton from "discourse/ui-kit/d-button";

module("Unit | ui-kit | DButton independent", function () {
  for (const shape of [
    "function",
    "object",
    "empty-object",
    "string",
    "number",
    "absent",
    "null",
    "false",
  ]) {
    for (const isIOS of [false, true]) {
      test(`Independent030eac matrix ${shape} iOS=${isIOS}`, async function (assert) {
        for (const immediate of [false, true]) {
          for (const forwardEvent of [false, true]) {
            for (const actionParam of [undefined, 0, { sentinel: true }]) {
              for (const navigation of [
                {},
                { route: "topic" },
                { href: "#independent" },
                { route: "topic", href: "#independent", routeModels: [1, 2] },
              ]) {
                for (const state of [
                  {},
                  { disabled: true },
                  { isLoading: true },
                  { disabled: true, isLoading: true },
                ]) {
                  const calls = [];
                  const routes = [];
                  const callback = (...args) => calls.push(args);
                  const action = {
                    function: callback,
                    object: { value: callback },
                    "empty-object": {},
                    string: "invalid",
                    number: 7,
                    absent: undefined,
                    null: null,
                    false: false,
                  }[shape];
                  const args = {
                    action,
                    actionParam,
                    forwardEvent,
                    immediate,
                    ...navigation,
                    ...state,
                  };
                  const event = new MouseEvent("click", { cancelable: true });
                  let stopped = false;
                  event.stopPropagation = () => (stopped = true);
                  const result = DButton.prototype._triggerAction.call(
                    {
                      args,
                      capabilities: { isIOS },
                      router: {
                        transitionTo: (...values) => routes.push(values),
                      },
                    },
                    event
                  );
                  const callable = shape === "function" || shape === "object";
                  const intercepted = Boolean(action || args.route);
                  assert.strictEqual(
                    calls.length,
                    callable && (isIOS || immediate) ? 1 : 0,
                    "only callable immediate/iOS actions run synchronously"
                  );
                  assert.strictEqual(
                    event.defaultPrevented,
                    intercepted,
                    "action/route owns the default even for unsupported truthy actions"
                  );
                  assert.strictEqual(
                    stopped,
                    intercepted,
                    "propagation follows interception"
                  );
                  assert.strictEqual(
                    result,
                    intercepted ? false : undefined,
                    "return contract is retained"
                  );
                  assert.deepEqual(
                    routes,
                    !action && args.route
                      ? [[args.route, ...(args.routeModels || [])]]
                      : [],
                    "truthy action takes precedence over route and href"
                  );
                  await settled();
                  assert.deepEqual(
                    calls,
                    callable
                      ? [forwardEvent ? [actionParam, event] : [actionParam]]
                      : [],
                    "exactly one call with the original parameter and optional event"
                  );
                }
              }
            }
          }
        }
      });
    }
  }

  for (const isIOS of [false, true]) {
    test(`Independent030eac object method keeps its receiver iOS=${isIOS}`, async function (assert) {
      let receiver;
      const handler = {
        value() {
          receiver = this;
        },
      };
      DButton.prototype._triggerAction.call(
        { args: { action: handler }, capabilities: { isIOS } },
        new MouseEvent("click")
      );
      await settled();
      assert.strictEqual(
        receiver,
        handler,
        "legacy action.value() binds this to the action object"
      );
    });
  }

  test("Independent030eac deferred object resolves value at invocation time", async function (assert) {
    const calls = [];
    const handler = { value: () => calls.push("stale") };
    DButton.prototype._triggerAction.call(
      { args: { action: handler }, capabilities: { isIOS: false } },
      new MouseEvent("click")
    );
    handler.value = () => calls.push("replacement");
    await settled();
    assert.deepEqual(
      calls,
      ["replacement"],
      "legacy deferred dispatch reads the current method"
    );
  });

  test("Independent030eac function with value property still calls the function", async function (assert) {
    const calls = [];
    const handler = () => calls.push("function");
    handler.value = () => calls.push("property");
    DButton.prototype._triggerAction.call(
      { args: { action: handler }, capabilities: { isIOS: true } },
      new MouseEvent("click")
    );
    assert.deepEqual(
      calls,
      ["function"],
      "typeof function never enters the object branch"
    );
  });
});
