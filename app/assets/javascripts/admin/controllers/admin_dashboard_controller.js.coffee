window.Discourse.AdminDashboardController = Ember.Controller.extend
  loading: true
  versionCheck: null

  upToDate: (->
    if @versionCheck
      @versionCheck.latest_version == @versionCheck.installed_version
    else
      true
  ).property('versionCheck')

  updateIconClasses: (->
    classes = "icon icon-warning-sign "
    if @get('versionCheck.critical_updates')
      classes += "critical-updates-available"
    else
      classes += "updates-available"
    classes
  ).property('versionCheck')
  
  priorityClass: (->
    if @get('versionCheck.critical_updates')
      'version-check critical'
    else
      'version-check normal'
  ).property('versionCheck')