import AppEvents from "discourse/services/app-events";
import { isTesting } from "discourse-common/config/environment";

let _skipUpdate;
let _rootElement;

export function configureEyeline(opts) {
  if (opts) {
    _skipUpdate = opts.skipUpdate;
    _rootElement = opts.rootElement;
  } else {
    _skipUpdate = isTesting();
    _rootElement = null;
  }
}

configureEyeline();

//  Track visible elements on the screen.
const Eyeline = function Eyeline(selector) {
  this.selector = selector;
  this.appEvents = AppEvents.create();
};

Eyeline.prototype.on = function (name, cb) {
  this.appEvents.on(name, cb);
};

Eyeline.prototype.off = function (name, cb) {
  this.appEvents.off(name, cb);
};

Eyeline.prototype.update = function () {
  if (_skipUpdate) {
    return;
  }

  const docViewTop = _rootElement
    ? $(_rootElement).scrollTop()
    : $(window).scrollTop();
  const windowHeight = _rootElement
    ? $(_rootElement).height()
    : $(window).height();
  const docViewBottom = docViewTop + windowHeight;
  const $elements = $(this.selector);
  const bottomOffset = _rootElement
    ? $elements.last().position()
    : $elements.last().offset();

  let atBottom = false;
  if (bottomOffset) {
    atBottom =
      bottomOffset.top <= docViewBottom && bottomOffset.top >= docViewTop;
  }

  let { appEvents } = this;
  return $elements.each((i, elem) => {
    const $elem = $(elem),
      elemTop = _rootElement ? $elem.position().top : $elem.offset().top,
      elemBottom = elemTop + $elem.height();

    let markSeen = false;

    // Make sure the element is visible
    if (!$elem.is(":visible")) {
      return true;
    }

    // It's seen if...
    // ...the element is vertically within the top and bottom
    if (elemTop <= docViewBottom && elemTop >= docViewTop) {
      markSeen = true;
    }

    // ...the element top is above the top and the bottom is below the bottom (large elements)
    if (elemTop <= docViewTop && elemBottom >= docViewBottom) {
      markSeen = true;
    }

    // ...we're at the bottom and the bottom of the element is visible (large bottom elements)
    if (atBottom && elemBottom >= docViewTop) {
      markSeen = true;
    }

    if (!markSeen) {
      return true;
    }

    // If you hit the bottom we mark all the elements as seen. Otherwise, just the first one
    if (!atBottom) {
      return false;
    }
    if (i === $elements.length - 1) {
      return appEvents.trigger("sawBottom", { detail: $elem });
    }
  });
};

export default Eyeline;
