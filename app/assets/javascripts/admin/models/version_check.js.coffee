window.Discourse.VersionCheck = Discourse.Model.extend({})

Discourse.VersionCheck.reopenClass
  find: ->
    $.ajax
      url: '/admin/version_check'
      dataType: 'json'
      success: (json) =>
        Discourse.VersionCheck.create(json)
