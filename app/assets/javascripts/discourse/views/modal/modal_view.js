/**
  A base class for helping us display modal content

  @class ModalView
  @extends Ember.ContainerView
  @namespace Discourse
  @module Discourse
**/
Discourse.ModalView = Ember.ContainerView.extend({
  childViews: ['modalHeaderView', 'modalBodyView', 'modalErrorsView'],
  classNames: ['modal', 'hidden'],
  classNameBindings: ['controller.currentView.modalClass'],
  elementId: 'discourse-modal',

  modalHeaderView: Ember.View.create({
    templateName: 'modal/modal_header',
    titleBinding: 'controller.currentView.title'
  }),
  modalBodyView: Ember.ContainerView.create({ currentViewBinding: 'controller.currentView' }),
  modalErrorsView: Ember.View.create({ templateName: 'modal/modal_errors' }),

  viewChanged: function() {
    this.set('modalErrorsView.errors', null);

    var view = this.get('controller.currentView');
    var modalView = this;
    if (view) {
      $('#modal-alert').hide();
      Em.run.schedule('afterRender', function() { modalView.$().modal('show'); });
    }
  }.observes('controller.currentView')

});


