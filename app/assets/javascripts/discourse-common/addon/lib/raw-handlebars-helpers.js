import { get } from "@ember/object";

export const RUNTIME_OPTIONS = {
  allowProtoPropertiesByDefault: true,
};

export function registerRawHelpers(hbs, handlebarsClass, owner) {
  if (!hbs.helpers) {
    hbs.helpers = Object.create(handlebarsClass.helpers);
  }

  lazyLoadHelpers(hbs, owner);

  if (hbs.__helpers_registered) {
    return;
  }
  hbs.__helpers_registered = true;

  hbs.helpers["get"] = function (context, options) {
    if (!context || !options.contexts) {
      return;
    }

    if (typeof context !== "string") {
      return context;
    }

    let firstContext = options.contexts[0];
    let val = firstContext[context];

    if (context.toString().startsWith("controller.")) {
      context = context.slice(context.indexOf(".") + 1);
    }

    return val === undefined ? get(firstContext, context) : val;
  };

  // #each .. in support (as format is transformed to this)
  hbs.registerHelper(
    "each",
    function (localName, inKeyword, contextName, options) {
      if (typeof contextName === "undefined") {
        return;
      }
      let list = get(this, contextName);
      let output = [];
      let innerContext = options.contexts[0];
      for (let i = 0; i < list.length; i++) {
        innerContext[localName] = list[i];
        output.push(options.fn(innerContext));
      }
      delete innerContext[localName];
      return output.join("");
    }
  );

  function stringCompatHelper(fn) {
    const old = hbs.helpers[fn];
    hbs.helpers[fn] = function (context, options) {
      return old.apply(this, [hbs.helpers.get(context, options), options]);
    };
  }

  // HACK: Ensure that the variable is resolved only once.
  // The "get" function will be called twice because both `if` and `unless`
  // helpers are patched to resolve the variable and `unless` is implemented
  // as not `if`. For example, for {{#unless var}} will generate a stack
  // trace like:
  //
  // - patched-unless("var")  "var" is resolved to its value, val
  // - unless(val)            unless is implemented as !if
  // - !patched-if(val)       val is already resolved, but it is resolved again
  // - !if(???)               at this point, ??? usually stands for undefined
  //
  // The following code ensures that patched-unless will call `if` directly,
  // `patched-unless("var")` will return `!if(val)`.
  const oldIf = hbs.helpers["if"];
  hbs.helpers["unless"] = function (context, options) {
    return oldIf.apply(this, [
      hbs.helpers.get(context, options),
      {
        fn: options.inverse,
        inverse: options.fn,
        hash: options.hash,
      },
    ]);
  };

  stringCompatHelper("if");
  stringCompatHelper("with");
}

function lazyLoadHelpers(hbs, owner) {
  // Reimplements `helperMissing` so that it triggers a lookup() for
  // a helper of that name. Means we don't need to eagerly load all
  // helpers/* files during boot.
  hbs.registerHelper("helperMissing", function (...args) {
    const opts = args[args.length - 1];
    if (opts?.name) {
      // Lookup and evaluate the relevant module. Raw helpers may be registered as a side effect
      owner.lookup(`helper:${opts.name}`);

      if (hbs.helpers[opts.name]) {
        // Helper now exists, invoke it
        return hbs.helpers[opts.name]?.call(this, ...arguments);
      } else {
        // Not a helper, treat as property
        return hbs.helpers["get"].call(this, ...arguments);
      }
    }
  });
}
