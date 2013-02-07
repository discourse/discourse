Discourse.StaticController.pages.forEach (page) ->
  window.Discourse["#{page.capitalize()}Route"] = Discourse.Route.extend
    renderTemplate: -> @render 'static'
    setupController: -> @controllerFor('static').loadPath("/#{page}")
