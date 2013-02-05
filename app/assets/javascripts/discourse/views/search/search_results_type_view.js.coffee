window.Discourse.SearchResultsTypeView = Ember.CollectionView.extend
  tagName: 'ul'


  itemViewClass: Ember.View.extend({
    tagName: 'li'
    templateName: (->
      "search/#{@get('parentView.type')}_result"
    ).property('parentView.type')
    classNameBindings: ['selectedClass', 'parentView.type']
    selectedIndexBinding: 'parentView.parentView.selectedIndex'
  
    # Is this row currently selected by the keyboard?
    selectedClass: (->
      return 'selected' if @get('content.index') == @get('selectedIndex')
      null
    ).property('selectedIndex')

  })

