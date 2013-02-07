window.Discourse.TopicListItemView = Ember.View.extend
  tagName: 'tr'
  templateName: 'list/topic_list_item'
  classNameBindings: ['content.archived', ':topic-list-item']
  attributeBindings: ['data-topic-id']

  'data-topic-id': (-> @get('content.id') ).property('content.id')

  init: ->
    @._super()
    @set('context', @get('content'))

  highlight: ->
    $topic = @.$()
    originalCol = $topic.css('backgroundColor')
    $topic.css(backgroundColor: "#ffffcc").animate(backgroundColor: originalCol, 2500)

  didInsertElement: ->

    if Discourse.get('transient.lastTopicIdViewed') == @get('content.id')
      Discourse.set('transient.lastTopicIdViewed', null)
      @highlight()
      return

    @highlight() if @get('content.highlightAfterInsert')

