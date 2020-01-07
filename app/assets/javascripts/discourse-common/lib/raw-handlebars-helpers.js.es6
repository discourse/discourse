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
  stringCompatHelper("if");
  stringCompatHelper("unless");
  stringCompatHelper("with");
}
