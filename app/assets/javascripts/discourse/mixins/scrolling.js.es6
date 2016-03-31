import debounce from 'discourse/lib/debounce';

/**
  This object provides the DOM methods we need for our Mixin to bind to scrolling
  methods in the browser. By removing them from the Mixin we can test them
  easier.
**/
const ScrollingDOMMethods = {
  bindOnScroll(onScrollMethod, name) {
    name = name || 'default';
    $(document).bind(`touchmove.discourse-${name}`, onScrollMethod);
    $(window).bind(`scroll.discourse-${name}`, onScrollMethod);
  },

  unbindOnScroll(name) {
    name = name || 'default';
    $(window).unbind(`scroll.discourse-${name}`);
    $(document).unbind(`touchmove.discourse-${name}`);
  },

  screenNotFull() {
    return $(window).height() > $("#main").height();
  }
};

const Scrolling = Ember.Mixin.create({

  // Begin watching for scroll events. By default they will be called at max every 100ms.
  // call with {debounce: N} for a diff time
  bindScrolling(opts) {
    opts = opts || { debounce: 100 };

    // So we can not call the scrolled event while transitioning
    const router = Discourse.__container__.lookup('router:main').router;

    let onScrollMethod = () => {
      if (router.activeTransition) { return; }
      return Ember.run.scheduleOnce('afterRender', this, 'scrolled');
    };

    if (opts.debounce) {
      onScrollMethod = debounce(onScrollMethod, opts.debounce);
    }

    ScrollingDOMMethods.bindOnScroll(onScrollMethod, opts.name);
  },

  screenNotFull: () => ScrollingDOMMethods.screenNotFull(),

  unbindScrolling(name) {
    ScrollingDOMMethods.unbindOnScroll(name);
  }
});

export { ScrollingDOMMethods };
export default Scrolling;
