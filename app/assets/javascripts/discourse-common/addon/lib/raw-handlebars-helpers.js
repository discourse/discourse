import { get } from "@ember/object";

export const RUNTIME_OPTIONS = {
  allowProtoPropertiesByDefault: true,
};

export function registerRawHelpers(hbs, handlebarsClass) {
  if (!hbs.helpers) {
    hbs.helpers = Object.create(handlebarsClass.helpers);
  }
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

    if (context.toString().indexOf("controller.") === 0) {
      context = context.slice(context.indexOf(".") + 1);
    }

    // This replaces:
    //return val === undefined ? get(firstContext, context) : val;

    // @see: https://api.emberjs.com/ember/3.28/functions/@ember%2Fobject/get
    // @see: https://github.com/emberjs/ember.js/blob/3537670c14883346e11e841fcb71333384fcbc87/packages/%40ember/-internals/metal/lib/property_get.ts#L47-L77
    /*
    GET AND SET

    If we are on a platform that supports accessors we can use those.
    Otherwise simulate accessors by looking up the property directly on the
    object.
    […]
    If you plan to run on IE8 and older browsers then you should use this
    method anytime you want to retrieve a property on an object that you don't
    know for sure is private. (Properties beginning with an underscore '_'
    are considered private.)

    On all newer browsers, you only need to use this method to retrieve
    properties if the property might not be defined on the object and you want
    to respect the `unknownProperty` handler. Otherwise you can ignore this
    method.
    […]
     */

    if (val === undefined) {
      let type = typeof firstContext;
      let isObject = type === 'object';
      let isFunction = type === 'function';
      let isObjectLike = isObject || isFunction;

      // replaces @ember/-internals/utils isPath
      // @see: https://github.com/emberjs/ember.js/blob/3537670c14883346e11e841fcb71333384fcbc87/packages/%40ember/-internals/metal/lib/path_cache.ts#L5-L7
      // @see: https://github.com/emberjs/ember.js/blob/255a0dd3c7de1187f4a2f61a97cf78bfff8f66a8/packages/%40ember/-internals/glimmer/lib/utils/bindings.ts#L70
      let isPath = context.indexOf('.') > -1;

      if (isPath) {
        if (isObjectLike) {
            // replaces @ember/object _getPath
            // @see: https://github.com/emberjs/ember.js/blob/3537670c14883346e11e841fcb71333384fcbc87/packages/%40ember/-internals/metal/lib/property_get.ts#L146-L159
            let obj = firstContext;
            let path = context;
            let parts = typeof path === 'string' ? path.split('.') : path;

            for (var i = 0; i < parts.length; i++) {
              if (obj === undefined || obj === null || obj.isDestroyed) {
                return undefined;
              }

              // TODO: remove recursive calls of 'get' - if possible
              obj = get(obj, parts[i]);
            }

            return obj;
        }
        return undefined;
      }

      // replaces @ember/object _getProp
      // https://github.com/emberjs/ember.js/blob/3537670c14883346e11e841fcb71333384fcbc87/packages/%40ember/-internals/metal/lib/property_get.ts#L115-L128
      if (isObject && !(context in firstContext) && typeof firstContext.unknownProperty === 'function') {
        return firstContext.unknownProperty(context);
      }
    }

    return val;
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
      for (let i = 0; i < list.length; i++) {
        let innerContext = {};
        innerContext[localName] = list[i];
        output.push(options.fn(innerContext));
      }
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
