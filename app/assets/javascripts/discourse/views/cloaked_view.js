/**
  A cloaked view is one that removes its content when scrolled off the screen

  @class CloakedView
  @extends Discourse.View
  @namespace Discourse
  @module Discourse
**/
Discourse.CloakedView = Discourse.View.extend({
  attributeBindings: ['style'],

  init: function() {
    this._super();
    this.uncloak();
  },


  /**
    Triggers the set up for rendering a view that is cloaked.

    @method uncloak
  */
  uncloak: function() {
    var containedView = this.get('containedView');
    if (!containedView) {
      this.setProperties({
        style: null,
        loading: false,
        containedView: this.createChildView(Discourse[this.get('cloaks')], { content: this.get('content') })
      });

      this.rerender();
    }
  },

  /**
    Removes the view from the DOM and tears down all observers.

    @method cloak
  */
  cloak: function() {
    var containedView = this.get('containedView'),
        self = this;

    if (containedView && this.get('state') === 'inDOM') {
      var style = 'height: ' + this.$().height() + 'px;';
      this.set('style', style);
      this.$().prop('style', style);

      // We need to remove the container after the height of the element has taken
      // effect.
      Ember.run.schedule('afterRender', function() {
        self.set('containedView', null);
        containedView.willDestroyElement();
        containedView.remove();
      });
    }
  },


  /**
    Render the cloaked view if applicable.

    @method render
  */
  render: function(buffer) {
    var containedView = this.get('containedView');
    if (containedView && containedView.get('state') !== 'inDOM') {
      containedView.renderToBuffer(buffer);
      containedView.transitionTo('inDOM');
      Em.run.schedule('afterRender', function() {
        containedView.didInsertElement();
      });
    }
  }

});
