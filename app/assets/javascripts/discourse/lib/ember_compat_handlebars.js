// keep IIF for simpler testing

// EmberCompatHandlebars is a mechanism for quickly rendering templates which is Ember aware
// templates are highly compatible with Ember so you don't need to worry about calling "get"
// and computed properties function, additionally it uses stringParams like Ember does

(function(){

  // compat with ie8 in case this gets picked up elsewhere
  var objectCreate = Object.create || function(parent) {
    function F() {}
    F.prototype = parent;
    return new F();
  };


  var RawHandlebars = Handlebars.create();

  RawHandlebars.helper = function() {};
  RawHandlebars.helpers = objectCreate(Handlebars.helpers);

  RawHandlebars.helpers.get = function(context, options){
    var firstContext =  options.contexts[0];
    var val = firstContext[context];

    if (val && val.isDescriptor) { return Em.get(firstContext, context); }
    val = val === undefined ? Em.get(firstContext, context): val;
    return val;
  };

  // adds compatability so this works with stringParams
  var stringCompatHelper = function(fn){

    var old = RawHandlebars.helpers[fn];
    RawHandlebars.helpers[fn] = function(context,options){
      return old.apply(this, [
          RawHandlebars.helpers.get(context,options),
          options
      ]);
    };
  };

  // #each .. in support (as format is transformed to this)
  RawHandlebars.registerHelper('each', function(localName,inKeyword,contextName,options){
    var list = Em.get(this, contextName);
    var output = [];
    var innerContext = Object.create(this);
    for (var i=0; i<list.length; i++) {
      innerContext[localName] = list[i];
      output.push(options.fn(innerContext));
    }
    return output.join('');
  });

  stringCompatHelper("if");
  stringCompatHelper("unless");
  stringCompatHelper("with");


  if (Handlebars.Compiler) {
    RawHandlebars.Compiler = function() {};
    RawHandlebars.Compiler.prototype = objectCreate(Handlebars.Compiler.prototype);
    RawHandlebars.Compiler.prototype.compiler = RawHandlebars.Compiler;

    RawHandlebars.JavaScriptCompiler = function() {};

    RawHandlebars.JavaScriptCompiler.prototype = objectCreate(Handlebars.JavaScriptCompiler.prototype);
    RawHandlebars.JavaScriptCompiler.prototype.compiler = RawHandlebars.JavaScriptCompiler;
    RawHandlebars.JavaScriptCompiler.prototype.namespace = "Discourse.EmberCompatHandlebars";

    function buildPath(blk, args) {

      var result = { type: "PathExpression",
                     data: false,
                     depth: blk.path.depth,
                     loc: blk.path.loc };

      // Server side precompile doesn't have jquery.extend
      Object.keys(args).forEach(function (a) {
        result[a] = args[a];
      });

      return result;
    }

    function replaceGet(ast) {
      var visitor = new Handlebars.Visitor();
      visitor.mutating = true;

      visitor.MustacheStatement = function(mustache) {
        if (!(mustache.params.length || mustache.hash)) {
          mustache.params[0] = mustache.path;
          mustache.path = buildPath(mustache, { parts: ['get'], original: 'get', strict: true, falsy: true });
        }
        return Handlebars.Visitor.prototype.MustacheStatement.call(this, mustache);
      };

      // rewrite `each x as |y|` as each y in x`
      // This allows us to use the same syntax in all templates
      visitor.BlockStatement = function(block) {
        if (block.path.original === 'each' && block.params.length === 1) {
          var paramName = block.program.blockParams[0];
          block.params = [ buildPath(block, { original: paramName }),
                           { type: "CommentStatement", value: "in" },
                           block.params[0] ];
          delete block.program.blockParams;
        }

        return Handlebars.Visitor.prototype.BlockStatement.call(this, block);
      };

      visitor.accept(ast);
    }

    RawHandlebars.precompile = function(value, asObject) {
      var ast = Handlebars.parse(value);
      replaceGet(ast);

      var options = {
        knownHelpers: {
          get: true
        },
        data: true,
        stringParams: true
      };

      asObject = asObject === undefined ? true : asObject;

      var environment = new RawHandlebars.Compiler().compile(ast, options);
      return new RawHandlebars.JavaScriptCompiler().compile(environment, options, undefined, asObject);
    };

    RawHandlebars.compile = function(string) {
      var ast = Handlebars.parse(string);
      replaceGet(ast);

      // this forces us to rewrite helpers
      var options = {  data: true, stringParams: true };
      var environment = new RawHandlebars.Compiler().compile(ast, options);
      var templateSpec = new RawHandlebars.JavaScriptCompiler().compile(environment, options, undefined, true);

      var template = RawHandlebars.template(templateSpec);
      template.isMethod = false;

      return template;
    };
  }

  RawHandlebars.get = function(ctx, property, options){
    if (options.types && options.data.view) {
      var view = options.data.view;
      return view.getStream ? view.getStream(property).value() : view.getAttr(property);
    } else {
      return Ember.get(ctx, property);
    }
  };

  Discourse.EmberCompatHandlebars = RawHandlebars;

})();
