import { addDecorator } from 'discourse/widgets/post-cooked';
import ComposerEditor from 'discourse/components/composer-editor';

let _decorateId = 0;
function decorate(klass, evt, cb) {
  const mixin = {};
  mixin["_decorate_" + (_decorateId++)] = function($elem) { cb($elem); }.on(evt);
  klass.reopen(mixin);
}

export function decorateCooked(container, cb) {
  addDecorator(cb);
  decorate(ComposerEditor, 'previewRefreshed', cb);
  decorate(container.lookupFactory('view:user-stream'), 'didInsertElement', cb);
}
