import { translateResults, searchContextDescription, getSearchKey, isValidSearchTerm } from "discourse/lib/search";
import showModal from 'discourse/lib/show-modal';
import { default as computed, observes } from 'ember-addons/ember-computed-decorators';
import Category from 'discourse/models/category';

const SortOrders = [
  {name: I18n.t('search.relevance'), id: 0},
  {name: I18n.t('search.latest_post'), id: 1, term: 'order:latest'},
  {name: I18n.t('search.most_liked'), id: 2, term: 'order:likes'},
  {name: I18n.t('search.most_viewed'), id: 3, term: 'order:views'},
];

export default Ember.Controller.extend({
  needs: ["application"],

  loading: Em.computed.not("model"),
  queryParams: ["q", "context_id", "context", "skip_context"],
  q: null,
  selected: [],
  context_id: null,
  context: null,
  searching: false,
  sortOrder: 0,
  sortOrders: SortOrders,

  @computed('model.posts')
  resultCount(posts){
    return posts && posts.length;
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

  @computed('searchTerm', 'searching')
  searchButtonDisabled(searchTerm, searching) {
    return !!(searching || !isValidSearchTerm(searchTerm));
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
    return Discourse.Utilities.escapeExpression(q);
  },

  _searchOnSortChange: true,

  setSearchTerm(term) {
    this._searchOnSortChange = false;
    if (term) {
      SortOrders.forEach((order) => {
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
  triggerSearch(){
    if (this._searchOnSortChange) {
      this.search();
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
    console.log(q);
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
    this.set("controllers.application.showFooter", !this.get("loading"));
  },

  canBulkSelect: Em.computed.alias('currentUser.staff'),

  search(){
    if (this.get("searching")) return;
    this.set("searching", true);

    const router = Discourse.__container__.lookup('router:main');

    var args = { q: this.get("searchTerm") };

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

    Discourse.ajax("/search", { data: args }).then(results => {
      const model = translateResults(results) || {};
      router.transientCache('lastSearch', { searchKey, model }, 5);
      this.set("model", model);
    }).finally(() => { this.set("searching",false); });
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

    refresh() {
      this.set('bulkSelectEnabled', false);
      this.get('selected').clear();
      this.search();
    },

    showSearchHelp() {
      // TODO: dupe code should be centralized
      Discourse.ajax("/static/search_help.html", { dataType: 'html' }).then((model) => {
        showModal('searchHelp', { model });
      });
    },

    search() {
      if (this.get("searchButtonDisabled")) return;
      this.search();
    }
  }
});
