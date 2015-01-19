var _decorateId = 0;

function decorate(klass, evt, cb) {
  var mixin = {};
  mixin["_decorate_" + (_decorateId++)] = function($elem) { cb($elem); }.on(evt);
  klass.reopen(mixin);
}

export function decorateCooked(container, cb) {
  var postView = container.lookupFactory('view:post');
  decorate(postView, 'postViewInserted', cb);
  decorate(postView, 'postViewUpdated', cb);
  decorate(container.lookupFactory('view:composer'), 'previewRefreshed', cb);
  decorate(container.lookupFactory('view:embedded-post'), 'previewRefreshed', cb);
  decorate(container.lookupFactory('view:user-stream'), 'didInsertElement', cb);
}
