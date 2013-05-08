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
    @param {String} typeFilter An optional filter to restrict the search by type
    @return {Promise} a promise that resolves the search results
  **/
  forTerm: function(term, typeFilter) {
    return Discourse.ajax('/search', {
      data: { term: term, type_filter: typeFilter }
    });
  }

}

