window.Discourse.EmailLog = Discourse.Model.extend({})

window.Discourse.EmailLog.reopenClass

  create: (attrs) ->
    attrs.user = Discourse.AdminUser.create(attrs.user) if attrs.user
    @_super(attrs)

  findAll: (filter)->
    result = Em.A()
    $.ajax
      url: "/admin/email_logs.json"
      data: {filter: filter}
      success: (logs) ->
        logs.each (log) -> result.pushObject(Discourse.EmailLog.create(log))
    result

