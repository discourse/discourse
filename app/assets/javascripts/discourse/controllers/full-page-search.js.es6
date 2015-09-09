import { translateResults, searchContextDescription, getSearchKey } from "discourse/lib/search";
import showModal from 'discourse/lib/show-modal';
import { default as computed, observes } from 'ember-addons/ember-computed-decorators';
import Category from 'discourse/models/category';

export default Ember.Controller.extend({
  needs: ["application"],

  loading: Em.computed.not("model"),
  queryParams: ["q", "context_id", "context", "skip_context"],
  q: null,
  selected: [],
  context_id: null,
  context: null,

  @computed('skip_context', 'context')
  searchContextEnabled: {
    get(skip,context){
      return (!skip && context) || skip === "false";
    },
    set(val) {
      this.set('skip_context', val ? "false" : "true" )
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
    return q && q.length > 0;
  },

  @observes('model')
  modelChanged() {
    if (this.get("searchTerm") !== this.get("q")) {
      this.set("searchTerm", this.get("q"));
    }
  },

  @observes('q')
  qChanged() {
    const model = this.get("model");
    if (model && this.get("model.q") !== this.get("q")) {
      this.set("searchTerm", this.get("q"));
      this.send("search");
    }
  },

  @observes('loading')
  _showFooter() {
    this.set("controllers.application.showFooter", !this.get("loading"));
  },

  canBulkSelect: Em.computed.alias('currentUser.staff'),

  search(){
    const router = Discourse.__container__.lookup('router:main');

    this.set("q", this.get("searchTerm"));
    this.set("model", null);

    var args = { q: this.get("searchTerm") };

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
    });
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
      this.get('selected').clear()
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
      this.search();
    }
  }
});
