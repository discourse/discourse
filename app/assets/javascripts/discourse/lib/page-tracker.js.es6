import deprecated from 'discourse-common/lib/deprecated';

const PageTracker = Ember.Object.extend(Ember.Evented);
let _pageTracker = PageTracker.create();

let _started = false;

const cache = {};
let transitionCount = 0;

export function setTransient(key, data, count) {
  cache[key] = {data, target: transitionCount + count};
}

export function getTransient(key) {
  return cache[key];
}

export function startPageTracking(router) {
  if (_started) { return; }

  router.on('didTransition', function() {
    this.send('refreshTitle');
    const url = Discourse.getURL(this.get('url'));

    // Refreshing the title is debounced, so we need to trigger this in the
    // next runloop to have the correct title.
    Em.run.next(() => _pageTracker.trigger('change', url, Discourse.get('_docTitle')));

    transitionCount++;
    _.each(cache, (v,k) => {
      if (v && v.target && v.target < transitionCount) {
        delete cache[k];
      }
    });
  });
  _started = true;
}

export function onPageChange(fn) {
  _pageTracker.on('change', fn);
}

// backwards compatibility
const BackwardsCompat = {
  current() {
    deprecated(`Using PageTracker.current() is deprecated. Your plugin should use the PluginAPI`);
    return _pageTracker;
  }
};

Discourse.PageTracker = BackwardsCompat;
export default BackwardsCompat;
