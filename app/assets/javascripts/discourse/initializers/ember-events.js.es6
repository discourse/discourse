export default {
  name: "ember-events",

  initialize: function () {

    // By default Ember listens to too many events. This tells it the only events
    // we're interested in.
    Ember.EventDispatcher.reopen({
      events: {
        touchstart  : 'touchStart',
        touchend    : 'touchEnd',
        touchcancel : 'touchCancel',
        keydown     : 'keyDown',
        keyup       : 'keyUp',
        keypress    : 'keyPress',
        mousedown   : 'mouseDown',
        mouseup     : 'mouseUp',
        contextmenu : 'contextMenu',
        click       : 'click',
        dblclick    : 'doubleClick',
        focusin     : 'focusIn',
        focusout    : 'focusOut',
        mouseenter  : 'mouseEnter',
        mouseleave  : 'mouseLeave',
        submit      : 'submit',
        input       : 'input',
        change      : 'change',
        dragstart   : 'dragStart',
        drag        : 'drag',
        dragenter   : 'dragEnter',
        dragleave   : 'dragLeave',
        dragover    : 'dragOver',
        drop        : 'drop',
        dragend     : 'dragEnd'
      }
    });
  }
};
