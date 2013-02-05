window.Discourse.HistoryView = Ember.View.extend
  templateName: 'history'
  title: 'History'
  modalClass: 'history-modal'

  loadSide: (side) ->
    if @get("version#{side}")
      orig = @get('originalPost')
      version = @get("version#{side}.number")

      if version == orig.get('version')
        @set("post#{side}", orig)
      else
        Discourse.Post.loadVersion orig.get('id'), version, (post) =>
          @set("post#{side}", post)

  changedLeftVersion: (-> @loadSide("Left") ).observes('versionLeft')
  changedRightVersion: (-> @loadSide("Right") ).observes('versionRight')


  didInsertElement: ->
    @set('loading', true)
    @set('postLeft', null)
    @set('postRight', null)

    @get('originalPost').loadVersions (result) =>
      @set('loading', false)
 
      @set('versionLeft', result.first())
      @set('versionRight', result.last())
      @set('versions', result)

    
