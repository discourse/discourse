import { addDecorator } from 'discourse/widgets/post-cooked';
import ComposerEditor from 'discourse/components/composer-editor';

let _decorateId = 0;
function decorate(klass, evt, cb) {
  const mixin = {};
  mixin["_decorate_" + (_decorateId++)] = function($elem) { cb($elem); }.on(evt);
  klass.reopen(mixin);
}

export function decorateCooked() {
  console.warn('`decorateCooked` has been removed. Use `getPluginApi(version).decorateCooked` instead');
}

class PluginApi {
  constructor(version, container) {
    this.version = version;
    this.container = container;
  }

  decorateCooked(cb) {
    addDecorator(cb);
    decorate(ComposerEditor, 'previewRefreshed', cb);
    decorate(this.container.lookupFactory('view:user-stream'), 'didInsertElement', cb);
  }
}

let _pluginv01;

export function getPluginApi(version) {
  if (version === "0.1") {
    if (!_pluginv01) {
      _pluginv01 = new PluginApi(version, Discourse.__container__);
    }
    return _pluginv01;
  }
}

