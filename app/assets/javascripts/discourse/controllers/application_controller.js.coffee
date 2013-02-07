window.Discourse.ApplicationController = Ember.Controller.extend

  needs: ['modal']

  showLogin: ->
    @get('controllers.modal')?.show(Discourse.LoginView.create())
