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


  var RawHandlebars = objectCreate(Handlebars);

  RawHandlebars.helper = function() {};
  RawHandlebars.helpers = objectCreate(Handlebars.helpers);

  RawHandlebars.helpers.get = function(context, options){
    var firstContext =  options.contexts[0];
    var val = firstContext[context];
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

  stringCompatHelper("each");
  stringCompatHelper("if");
  stringCompatHelper("unless");
  stringCompatHelper("with");


  RawHandlebars.Compiler = function() {};
  RawHandlebars.Compiler.prototype = objectCreate(Handlebars.Compiler.prototype);
  RawHandlebars.Compiler.prototype.compiler = RawHandlebars.Compiler;

  RawHandlebars.JavaScriptCompiler = function() {};

  RawHandlebars.JavaScriptCompiler.prototype = objectCreate(Handlebars.JavaScriptCompiler.prototype);
  RawHandlebars.JavaScriptCompiler.prototype.compiler = RawHandlebars.JavaScriptCompiler;
  RawHandlebars.JavaScriptCompiler.prototype.namespace = "Discourse.EmberCompatHandlebars";


  RawHandlebars.Compiler.prototype.mustache = function(mustache) {
    if ( !(mustache.params.length || mustache.hash)) {

      var id = new Handlebars.AST.IdNode([{ part: 'get' }]);

      mustache = new Handlebars.AST.MustacheNode([id].concat([mustache.id]), mustache.hash, mustache.escaped);
    }

    return Handlebars.Compiler.prototype.mustache.call(this, mustache);
  };

  RawHandlebars.precompile = function(value, asObject) {
    var ast = Handlebars.parse(value);

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
    // this forces us to rewrite helpers
    var options = {  data: true, stringParams: true };
    var environment = new RawHandlebars.Compiler().compile(ast, options);
    var templateSpec = new RawHandlebars.JavaScriptCompiler().compile(environment, options, undefined, true);

    var template = RawHandlebars.template(templateSpec);

    return template;
  };

  Discourse.EmberCompatHandlebars = RawHandlebars;

})();
