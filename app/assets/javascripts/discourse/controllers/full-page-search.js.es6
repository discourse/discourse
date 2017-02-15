import { ajax } from 'discourse/lib/ajax';
import { translateResults, searchContextDescription, getSearchKey, isValidSearchTerm } from "discourse/lib/search";
import { default as computed, observes } from 'ember-addons/ember-computed-decorators';
import Category from 'discourse/models/category';
import { escapeExpression } from 'discourse/lib/utilities';
import { setTransient } from 'discourse/lib/page-tracker';
import { iconHTML } from 'discourse-common/helpers/fa-icon';

const SortOrders = [
  {name: I18n.t('search.relevance'), id: 0},
  {name: I18n.t('search.latest_post'), id: 1, term: 'order:latest'},
  {name: I18n.t('search.most_liked'), id: 2, term: 'order:likes'},
  {name: I18n.t('search.most_viewed'), id: 3, term: 'order:views'},
];

export default Ember.Controller.extend({
  application: Ember.inject.controller(),
  bulkSelectEnabled: null,

  loading: Em.computed.not("model"),
  queryParams: ["q", "expanded", "context_id", "context", "skip_context"],
  q: null,
  selected: [],
  expanded: false,
  context_id: null,
  context: null,
  searching: false,
  sortOrder: 0,
  sortOrders: SortOrders,
  invalidSearch: false,

  @computed('model.posts')
  resultCount(posts) {
    return posts && posts.length;
  },

  @computed('resultCount')
  hasResults(resultCount) {
    return (resultCount || 0) > 0;
  },

  @computed('q')
  hasAutofocus(q) {
    return Em.isEmpty(q);
  },

  @computed('skip_context', 'context')
  searchContextEnabled: {
    get(skip,context){
      return (!skip && context) || skip === "false";
    },
    set(val) {
      this.set('skip_context', val ? "false" : "true" );
    }
  },

  @computed('context', 'context_id')
  searchContextDescription(context, id){
    var name = id;
    if (context === 'category') {
      var category = Category.findById(id);
      if (!category) {return;}

      name = category.get('name');
    }
    return searchContextDescription(context, name);
  },

  @computed('q')
  searchActive(q){
    return isValidSearchTerm(q);
  },

  @computed('q')
  noSortQ(q) {
    if (q) {
      SortOrders.forEach((order) => {
        if (q.indexOf(order.term) > -1){
          q = q.replace(order.term, "");
          q = q.trim();
        }
      });
    }
    return escapeExpression(q);
  },

  _searchOnSortChange: true,

  setSearchTerm(term) {
    this._searchOnSortChange = false;
    if (term) {
      SortOrders.forEach(order => {
        if (term.indexOf(order.term) > -1){
          this.set('sortOrder', order.id);
          term = term.replace(order.term, "");
          term = term.trim();
        }
      });
    }
    this._searchOnSortChange = true;
    this.set('searchTerm', term);
  },

  @observes('sortOrder')
  triggerSearch() {
    if (this._searchOnSortChange) {
      this._search();
    }
  },

  @observes('model')
  modelChanged() {
    if (this.get("searchTerm") !== this.get("q")) {
      this.setSearchTerm(this.get("q"));
    }
  },

  @computed('q')
  showLikeCount(q) {
    return q && q.indexOf("order:likes") > -1;
  },

  @observes('q')
  qChanged() {
    const model = this.get("model");
    if (model && this.get("model.q") !== this.get("q")) {
      this.setSearchTerm(this.get("q"));
      this.send("search");
    }
  },

  @observes('loading')
  _showFooter() {
    this.set("application.showFooter", !this.get("loading"));
  },

  @computed('hasResults')
  canBulkSelect(hasResults) {
    return this.currentUser && this.currentUser.staff && hasResults;
  },

  @computed('expanded')
  canCreateTopic(expanded) {
    return this.currentUser && !this.site.mobileView && !expanded;
  },

  @computed('expanded')
  searchAdvancedIcon(expanded) {
    return iconHTML(expanded ? "caret-down" : "caret-right");
  },

  _search() {
    if (this.get("searching")) { return; }

    this.set('invalidSearch', false);
    const searchTerm = this.get('searchTerm');
    if (!isValidSearchTerm(searchTerm)) {
      this.set('invalidSearch', true);
      return;
    }

    this.set("searching", true);
    this.set('bulkSelectEnabled', false);
    this.get('selected').clear();

    var args = { q: searchTerm };

    const sortOrder = this.get("sortOrder");
    if (sortOrder && SortOrders[sortOrder].term) {
      args.q += " " + SortOrders[sortOrder].term;
    }

    this.set("q", args.q);
    this.set("model", null);

    const skip = this.get("skip_context");
    if ((!skip && this.get('context')) || skip==="false"){
      args.search_context = {
        type: this.get('context'),
        id: this.get('context_id')
      };
    }

    const searchKey = getSearchKey(args);

    ajax("/search", { data: args }).then(results => {
      const model = translateResults(results) || {};
      setTransient('lastSearch', { searchKey, model }, 5);
      this.set("model", model);
    }).finally(() => this.set("searching", false));
  },

  actions: {

    selectAll() {
      this.get('selected').addObjects(this.get('model.posts').map(r => r.topic));
      // Doing this the proper way is a HUGE pain,
      // we can hack this to work by observing each on the array
      // in the component, however, when we select ANYTHING, we would force
      // 50 traversals of the list
      // This hack is cheap and easy
      $('.fps-result input[type=checkbox]').prop('checked', true);
    },

    clearAll() {
      this.get('selected').clear();
      $('.fps-result input[type=checkbox]').prop('checked', false);
    },

    toggleBulkSelect() {
      this.toggleProperty('bulkSelectEnabled');
      this.get('selected').clear();
    },

    search() {
      this._search();
    },

    toggleAdvancedSearch() {
      this.toggleProperty('expanded');
    }
  }
});
