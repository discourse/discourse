import { get } from "@ember/object";

export function registerRawHelpers(hbs, handlebarsClass) {
  if (!hbs.helpers) {
    hbs.helpers = Object.create(handlebarsClass.helpers);
  }

  hbs.helpers["get"] = function(context, options) {
    if (!context || !options.contexts) {
      return;
    }

    if (typeof context !== "string") {
      return context;
    }

    let firstContext = options.contexts[0];
    let val = firstContext[context];

    if (context.toString().indexOf("controller.") === 0) {
      context = context.slice(context.indexOf(".") + 1);
    }

    return val === undefined ? get(firstContext, context) : val;
  };

  // #each .. in support (as format is transformed to this)
  hbs.registerHelper("each", function(
    localName,
    inKeyword,
    contextName,
    options
  ) {
    var list = get(this, contextName);
    var output = [];
    var innerContext = Object.create(this);
    for (var i = 0; i < list.length; i++) {
      innerContext[localName] = list[i];
      output.push(options.fn(innerContext));
    }
    return output.join("");
  });

  function stringCompatHelper(fn) {
    const old = hbs.helpers[fn];
    hbs.helpers[fn] = function(context, options) {
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
  hbs.helpers["unless"] = function(context, options) {
    return oldIf.apply(this, [
      hbs.helpers.get(context, options),
      {
        fn: options.inverse,
        inverse: options.fn,
        hash: options.hash
      }
    ]);
  };

  stringCompatHelper("if");
  stringCompatHelper("with");
}
