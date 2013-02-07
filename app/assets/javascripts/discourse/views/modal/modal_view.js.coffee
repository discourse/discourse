window.Discourse.ModalView = Ember.ContainerView.extend
  childViews: ['modalHeaderView', 'modalBodyView', 'modalErrorsView']
  classNames: ['modal', 'hidden']
  classNameBindings: ['controller.currentView.modalClass']
  elementId: 'discourse-modal'

  modalHeaderView: Ember.View.create
    templateName: 'modal/modal_header'
    titleBinding: 'controller.currentView.title'

  modalBodyView: Ember.ContainerView.create(currentViewBinding: 'controller.currentView')
  modalErrorsView: Ember.View.create(templateName: 'modal/modal_errors')

  viewChanged: (->

    @set('modalErrorsView.errors', null)
    if view = @get('controller.currentView')
      $('#modal-alert').hide()
      Em.run.next => @.$().modal('show')

  ).observes('controller.currentView')

