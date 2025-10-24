import { setInternalHelperManager } from "@glimmer/manager";
import {
  createUnboundRef,
  isInvokableRef,
  updateRef,
  valueForRef,
} from "@glimmer/reference";
import { get } from "@ember/-internals/metal";
import { flaggedInstrument } from "@ember/instrumentation";
import { join } from "@ember/runloop";
import deprecated from "discourse/lib/deprecated";

function NOOP(args) {
  return args;
}

function makeArgsProcessor(valuePathRef, actionArgsRef) {
  let mergeArgs;

  if (actionArgsRef.length > 0) {
    mergeArgs = (args) => {
      return actionArgsRef.map(valueForRef).concat(args);
    };
  }

  let readValue;

  if (valuePathRef) {
    readValue = (args) => {
      let valuePath = valueForRef(valuePathRef);

      if (valuePath && args.length > 0) {
        args[0] = get(args[0], valuePath);
      }

      return args;
    };
  }

  if (mergeArgs && readValue) {
    return (args) => {
      return readValue(mergeArgs(args));
    };
  } else {
    return mergeArgs || readValue || NOOP;
  }
}

function makeClosureAction(context, target, action, processArgs) {
  let self;
  let fn;

  if (typeof action === "string") {
    self = target;
    let value = target.actions?.[action];
    fn = value;
  } else if (typeof action === "function") {
    self = context;
    fn = action;
  }

  return (...args) => {
    let payload = { target: self, args, label: "@glimmer/closure-action" };
    return flaggedInstrument("interaction.ember-action", payload, () => {
      return join(self, fn, ...processArgs(args));
    });
  };
}

function makeDynamicClosureAction(context, targetRef, actionRef, processArgs) {
  const action = valueForRef(actionRef);

  return (...args) => {
    return makeClosureAction(
      context,
      valueForRef(targetRef),
      action,
      processArgs
    )(...args);
  };
}

function invokeRef(value) {
  updateRef(this, value);
}

// a port of ember's builtin action helper
export default setInternalHelperManager(({ named, positional }) => {
  deprecated(
    `Usage of the \`(action)\` helper is deprecated. Migrate to native functions and function invocation.`,
    {
      id: "discourse.template-action",
      url: "https://deprecations.emberjs.com/id/template-action",
    }
  );

  let [context, action, ...restArgs] = positional;

  let target = "target" in named ? named["target"] : context;
  let processArgs = makeArgsProcessor(
    ("value" in named && named["value"]) || false,
    restArgs
  );

  let fn;
  if (isInvokableRef(action)) {
    fn = makeClosureAction(action, action, invokeRef, processArgs);
  } else {
    fn = makeDynamicClosureAction(
      valueForRef(context),
      target,
      action,
      processArgs
    );
  }

  return createUnboundRef(fn, "(result of an `action` helper)");
}, {});
