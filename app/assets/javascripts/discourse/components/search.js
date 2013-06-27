/**
  This component helps with Searching

  @class Search
  @namespace Discourse
  @module Discourse
**/
Discourse.Search = {

  /**
    Search for a term, with an optional filter.

    @method forTerm
    @param {String} term The term to search for
    @param {Object} opts Options for searching
      @param {String} opts.typeFilter Filter our results to one type only
      @param {Ember.Object} opts.searchContext data to help searching within a context (say, a category or user)
    @return {Promise} a promise that resolves the search results
  **/
  forTerm: function(term, opts) {
    if (!opts) opts = {};

    // Only include the data we have
    var data = { term: term };
    if (opts.typeFilter) data.type_filter = opts.typeFilter;

    if (opts.searchContext) {
      data.search_context = {
        type: opts.searchContext.type,
        id: opts.searchContext.id
      };
    }

    return Discourse.ajax('/search', { data: data });
  }

};

