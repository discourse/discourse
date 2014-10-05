function decorate(klass, evt, cb) {
  var mixin = {};
  mixin["_decorate_" + new Date().getTime().toString()] = function($elem) { cb($elem); }.on(evt);
  klass.reopen(mixin);
}

export function decorateCooked(container, cb) {
  decorate(Discourse.PostView, 'postViewInserted', cb);
  decorate(container.lookupFactory('view:composer'), 'previewRefreshed', cb);
  decorate(container.lookupFactory('view:embedded-post'), 'previewRefreshed', cb);
  decorate(container.lookupFactory('view:user-stream'), 'didInsertElement', cb);
}
