Discourse.Dialect.inlineBetween({
  start: '[poll]',
  stop: '[/poll]',
  rawContents: true,
  emitter: function(contents) {
    var list = Discourse.Dialect.cook(contents, {});
    return ['div', {class: 'poll-ui'}, list];
  }
});
