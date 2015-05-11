import Ember from 'ember';
import ListItemViewMixin from './list-item-view-mixin';

var get = Ember.get, set = Ember.set;

/**
  The `Ember.ListItemView` view class renders a
  [div](https://developer.mozilla.org/en/HTML/Element/div) HTML element
  with `ember-list-item-view` class. It allows you to specify a custom item
  handlebars template for `Ember.ListView`.

  Example:

  ```handlebars
  <script type="text/x-handlebars" data-template-name="row_item">
    {{name}}
  </script>
  ```

  ```javascript
  App.ListView = Ember.ListView.extend({
    height: 500,
    rowHeight: 20,
    itemViewClass: Ember.ListItemView.extend({templateName: "row_item"})
  });
  ```

  @extends Ember.View
  @class ListItemView
  @namespace Ember
*/
export default Ember.View.extend(ListItemViewMixin, {
  updateContext: function(newContext) {
    var context = get(this, 'context');

    Ember.instrument('view.updateContext.render', this, function() {
      if (context !== newContext) {
        set(this, 'context', newContext);
        if (newContext && newContext.isController) {
          set(this, 'controller', newContext);
        }
      }
    }, this);
  },

  rerender: function () {
    if (this.isDestroying || this.isDestroyed) {
      return;
    }

    return this._super.apply(this, arguments);
  },

  _contextDidChange: Ember.observer(function () {
    Ember.run.once(this, this.rerender);
  }, 'context', 'controller')
});
