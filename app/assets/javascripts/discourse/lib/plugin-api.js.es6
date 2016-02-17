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
  decorate(container.lookupFactory('view:composer'), 'previewRefreshed', cb);
  decorate(container.lookupFactory('view:embedded-post'), 'didInsertElement', cb);
  decorate(container.lookupFactory('view:user-stream'), 'didInsertElement', cb);
}

// This is backported so plugins in the new format will not raise errors
//
// To upgrade your plugin for backwards compatibility, you can add code in this
// form:
//
//   function newApiCode(api) {
//     // api.xyz();
//   }
//
//   function oldCode() {
//     // your pre-PluginAPI code goes here. You will be able to delete this
//     // code once the `PluginAPI` has been rolled out to all versions of
//     // Discourse you want to support.
//   }
//
//   // `newApiCode` will use API version 0.1, if no API support then
//   // `oldCode` will be called
//   withPluginApi('0.1', newApiCode, { noApi: oldCode });
//
export function withPluginApi(version, apiCodeCallback, opts) {
  console.warn(`Plugin API v${version} is not supported`);

  if (opts && opts.noApi) {
    return opts.noApi();
  }
}
