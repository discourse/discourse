import ComposerEditor from 'discourse/components/composer-editor';

let _decorateId = 0;
function decorate(klass, evt, cb) {
  const mixin = {};
  mixin["_decorate_" + (_decorateId++)] = function($elem) { cb($elem); }.on(evt);
  klass.reopen(mixin);
}

export function decorateCooked(container, cb) {
  const postView = container.lookupFactory('view:post');
  decorate(postView, 'postViewInserted', cb);
  decorate(postView, 'postViewUpdated', cb);
  decorate(ComposerEditor, 'previewRefreshed', cb);
  decorate(container.lookupFactory('view:embedded-post'), 'didInsertElement', cb);
  decorate(container.lookupFactory('view:user-stream'), 'didInsertElement', cb);
}

// Will be backported so plugins in the new format will not raise errors
export function withPluginApi(version) {
  console.warn(`Plugin API v${version} is not supported`);
}
