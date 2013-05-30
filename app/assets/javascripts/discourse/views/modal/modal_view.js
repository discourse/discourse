/**
  A base class for helping us display modal content

  @class ModalView
  @extends Ember.ContainerView
  @namespace Discourse
  @module Discourse
**/
Discourse.ModalView = Discourse.View.extend({
  elementId: 'discourse-modal',
  templateName: 'modal/modal',
  classNameBindings: [':modal', ':hidden', 'controller.modalClass']
});


