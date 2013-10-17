/**
  Our own containerView with a helper method for attaching views

  @class ContainerView
  @extends Ember.ContainerView
  @namespace Discourse
  @uses Discourse.Presence
  @module Discourse
**/
Discourse.ContainerView = Ember.ContainerView.extend(Discourse.Presence, {

  /**
    Attaches a view and wires up the container properly

    @method attachViewWithArgs
    @param {Object} viewArgs The arguments to pass when creating the view
    @param {Class} klass The view class we want to create
  **/
  attachViewWithArgs: function(viewArgs, viewClass) {
    if (!viewClass) { viewClass = Ember.View.extend(); }
    var view = this.createChildView(viewClass, viewArgs);
    this.pushObject(view);
  },

  /**
    Attaches a view with no arguments and wires up the container properly

    @method attachViewClass
    @param {Class} klass The view class we want to create
  **/
  attachViewClass: function(viewClass) {
    this.attachViewWithArgs(null, viewClass);
  }

});