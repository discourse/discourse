import Ember from 'ember';
import ListItemViewMixin from './list-item-view-mixin';

var get = Ember.get, set = Ember.set;

export default Ember.View.extend(ListItemViewMixin, {
  prepareForReuse: Ember.K,

  init: function () {
    this._super();
    var context = Ember.ObjectProxy.create();
    this.set('context', context);
    this._proxyContext = context;
  },

  isVisible: Ember.computed('context.content', function () {
    return !!this.get('context.content');
  }),

  updateContext: function (newContext) {
    var context = get(this._proxyContext, 'content');

    // Support old and new Ember versions
    var state = this._state || this.state;

    if (context !== newContext) {
      if (state === 'inDOM') {
        this.prepareForReuse(newContext);
      }

      set(this._proxyContext, 'content', newContext);

      if (newContext && newContext.isController) {
        set(this, 'controller', newContext);
      }
    }
  }
});
