import wrap from "discourse-common/lib/wrap";

export function DOMNotReadyError() { }
DOMNotReadyError.prototype = new Error();

export default function changesDOM(target, key, descriptor) {
  const checkForDOM = function() {
    if (!this.element || this.isDestroying || this.isDestroyed) {
      throw new DOMNotReadyError();
    }
  };

  return wrap(checkForDOM, DOMNotReadyError).call(this, target, key, descriptor);
}
