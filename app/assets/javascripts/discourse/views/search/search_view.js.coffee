window.Discourse.SearchView = Ember.View.extend Discourse.Presence,
  tagName: 'div'
  classNames: ['d-dropdown']
  elementId: 'search-dropdown'
  templateName: 'search'

  didInsertElement: ->
    # Delegate ESC to the composer
    $('body').on 'keydown.search', (e) =>
      if $('#search-dropdown').is(':visible')
        switch e.which
          when 13
            @select()
          when 38 # up arrow
            @moveUp()
          when 40 # down arrow
            @moveDown()

  searchPlaceholder: (->
    Em.String.i18n("search.placeholder")
  ).property()

  # If we need to perform another search
  newSearchNeeded: (->
    @set('noResults', false)
    if @present('term')
      @set('loading', true)
      @searchTerm(@get('term'), @get('typeFilter'))
    else
      @set('results', null)
    @set('selectedIndex', 0)
  ).observes('term', 'typeFilter')

  showCancelFilter: (->
    return false if @get('loading')
    return @present('typeFilter')
  ).property('typeFilter', 'loading')

  termChanged: (->
    @cancelType()
  ).observes('term')

  # We can re-order them based on the context
  content: (->
    if results = @get('results')
      # Make it easy to find the results by type
      results_hashed = {}
      results.each (r) -> results_hashed[r.type] = r

      path = Discourse.get('router.currentState.path')

      # Default order
      order = ['topic', 'category', 'user']

      results = (order.map (o) -> results_hashed[o]).without(undefined)

      index = 0
      results.each (result) ->
        result.results.each (item) -> item.index = index++

    results
  ).property('results')

  updateProgress: (->
    if results = @get('results')
      @set('noResults', results.length == 0)
    @set('loading', false)
  ).observes('results')

  searchTerm: (term, typeFilter) ->
    if @currentSearch
      @currentSearch.abort()
      @currentSearch = null

    @searcher = @searcher || Discourse.debounce((term, typeFilter) =>
      @currentSearch = $.ajax
        url: '/search'
        data:
          term: term
          type_filter: typeFilter
        success: (results) =>
          @set('results', results)
    , 300)

    @searcher(term, typeFilter)

  resultCount: (->
    return 0 if @blank('content')
    count = 0
    @get('content').each (result) ->
      count += result.results.length
    count
  ).property('content')

  moreOfType: (e) ->
    @set('typeFilter', e.context)
    false

  cancelType: ->
    @set('typeFilter', null)
    false

  moveUp: ->
    return if @get('selectedIndex') == 0
    @set('selectedIndex', @get('selectedIndex') - 1)

  moveDown: ->
    return if @get('resultCount') == (@get('selectedIndex') + 1)
    @set('selectedIndex', @get('selectedIndex') + 1)

  select: ->
    return if @get('loading')
    href = $('#search-dropdown li.selected a').prop('href')
    Discourse.routeTo(href) if href
    false
