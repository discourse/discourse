Discourse.Dialect.inlineBetween({
  start: '\\(',
  stop: '\\)',
  rawContents: true,
  emitter: function(contents) { return '$'+contents+'$';  }
});

Discourse.Dialect.inlineBetween({
  start: '$',
  stop: '$',
  rawContents: true,
  emitter: function(contents) { return '$'+contents+'$';  }
});

Discourse.Dialect.replaceBlock({
  start: /(\\\[)([\s\S]*)/,
  stop: '\\]',
  rawContents: true,
  emitter: function(contents) { return '\\['+contents+'\\]';  }
});

Discourse.Dialect.replaceBlock({
  start: /(\$\$)([\s\S]*)/,
  stop: '$$',
  rawContents: true,
  emitter: function(contents) { return '$$'+contents+'$$';  }
});

Discourse.Dialect.replaceBlock({
  start: /(\\begin{align})([\s\S]*)/,
  stop: '\\end{align}',
  rawContents: true,
  emitter: function(contents) { return '\\begin{align}'+ contents +'\\end{align}';  }
});

Discourse.Dialect.replaceBlock({
  start: /(\\begin{align*})([\s\S]*)/,
  stop: '\\end{align*}',
  rawContents: true,
  emitter: function(contents) { return '\\begin{align*}'+ contents +'\\end{align*}';  }
});

Discourse.Dialect.replaceBlock({
  start: /(\\begin{gather})([\s\S]*)/,
  stop: '\\end{gather}',
  rawContents: true,
  emitter: function(contents) { return '\\begin{gather}'+ contents +'\\end{gather}';  }
});

Discourse.Dialect.replaceBlock({
  start: /(\\begin{gather*})([\s\S]*)/,
  stop: '\\end{gather*}',
  rawContents: true,
  emitter: function(contents) { return '\\begin{gather*}'+ contents +'\\end{gather*}';  }
});

Discourse.Dialect.replaceBlock({
  start: /(\\begin{equation})([\s\S]*)/,
  stop: '\\end{equation}',
  rawContents: true,
  emitter: function(contents) { return '\\begin{equation}'+ contents +'\\end{equation}';  }
});

Discourse.Dialect.replaceBlock({
  start: /(\\begin{equation*})([\s\S]*)/,
  stop: '\\end{equation*}',
  rawContents: true,
  emitter: function(contents) { return '\\begin{equation*}'+ contents +'\\end{equation*}';  }
});