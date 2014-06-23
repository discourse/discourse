/**
  Support for various code blocks
**/

var acceptableCodeClasses =
  ["lang-auto", "1c", "actionscript", "apache", "applescript", "avrasm", "axapta", "bash", "brainfuck",
   "clojure", "cmake", "coffeescript", "cpp", "cs", "css", "d", "delphi", "diff", "xml", "django", "dos",
   "erlang-repl", "erlang", "glsl", "go", "handlebars", "haskell", "http", "ini", "java", "javascript",
   "json", "lisp", "lua", "markdown", "matlab", "mel", "nginx", "objectivec", "parser3", "perl", "php",
   "profile", "python", "r", "rib", "rsl", "ruby", "rust", "scala", "smalltalk", "sql", "tex", "text",
   "vala", "vbscript", "vhdl"];

Discourse.Dialect.replaceBlock({
  start: /^`{3}([^\n\[\]]+)?\n?([\s\S]*)?/gm,
  stop: '```',
  emitter: function(blockContents, matches) {

    var klass = Discourse.SiteSettings.default_code_lang;
    if (matches[1] && acceptableCodeClasses.indexOf(matches[1]) !== -1) {
      klass = matches[1];
    }
    return ['p', ['pre', ['code', {'class': klass}, blockContents.join("\n") ]]];
  }
});

// Ensure that content in a code block is fully escaped. This way it's not white listed
// and we can use HTML and Javascript examples.
Discourse.Dialect.on('parseNode', function (event) {
  var node = event.node,
      path = event.path;

  if (node[0] === 'code') {
    var contents = node[node.length-1],
        regexp;

    if (path && path[path.length-1] && path[path.length-1][0] && path[path.length-1][0] === "pre") {
      regexp = / +$/g;

    } else {
      regexp = /^ +| +$/g;
    }
    node[node.length-1] = Handlebars.Utils.escapeExpression(contents.replace(regexp,''));
  }
});

Discourse.Dialect.replaceBlock({
  start: /(<pre[^\>]*\>)([\s\S]*)/igm,
  stop: '</pre>',
  rawContents: true,
  skipIfTradtionalLinebreaks: true,

  emitter: function(blockContents) {
    return ['p', ['pre', blockContents.join("\n")]];
  }
});
