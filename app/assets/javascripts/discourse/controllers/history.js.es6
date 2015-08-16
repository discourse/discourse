import ModalFunctionality from 'discourse/mixins/modal-functionality';
import { categoryBadgeHTML } from 'discourse/helpers/category-link';
import computed from 'ember-addons/ember-computed-decorators';

// This controller handles displaying of history
export default Ember.Controller.extend(ModalFunctionality, {
  loading: true,
  viewMode: "side_by_side",
  revisionsTextKey: "post.revisions.controls.comparing_previous_to_current_out_of_total",

  _changeViewModeOnMobile: function() {
    if (Discourse.Mobile.mobileView) { this.set("viewMode", "inline"); }
  }.on("init"),

  refresh(postId, postVersion) {
    this.set("loading", true);

    var self = this;
    Discourse.Post.loadRevision(postId, postVersion).then(function (result) {
      self.setProperties({ loading: false, model: result });
    });
  },

  hide(postId, postVersion) {
    var self = this;
    Discourse.Post.hideRevision(postId, postVersion).then(function () {
      self.refresh(postId, postVersion);
    });
  },

  show(postId, postVersion) {
    var self = this;
    Discourse.Post.showRevision(postId, postVersion).then(function () {
      self.refresh(postId, postVersion);
    });
  },

  createdAtDate: function() { return moment(this.get("created_at")).format("LLLL"); }.property("created_at"),

  @computed('model.current_version')
  previousVersion(current) { return current - 1; },

  @computed('model.current_revision', 'model.previous_revision')
  displayGoToPrevious(current, prev) {
    return prev && current > prev;
  },

  displayRevisions: Ember.computed.gt("model.version_count", 2),
  displayGoToFirst: Ember.computed.gt('model.current_revision', 'model.first_revision'),
  displayGoToNext: Ember.computed.lt("model.current_revision", "model.next_revision"),
  displayGoToLast: Ember.computed.lt("model.current_revision", "model.next_revision"),

  @computed('model.previous_hidden', 'loading')
  displayShow: function(prevHidden, loading) {
    return prevHidden && this.currentUser.get('staff') && !loading;
  },

  @computed('model.previous_hidden', 'loading')
  displayHide: function(prevHidden, loading) {
    return !prevHidden && this.currentUser.get('staff') && !loading;
  },

  isEitherRevisionHidden: Ember.computed.or("model.previous_hidden", "model.current_hidden"),

  @computed('model.previous_hidden', 'model.current_hidden', 'displayingInline')
  hiddenClasses(prevHidden, currentHidden, displayingInline) {
    if (displayingInline) {
      return this.get("isEitherRevisionHidden") ? "hidden-revision-either" : null;
    } else {
      var result = [];
      if (prevHidden) { result.push("hidden-revision-previous"); }
      if (currentHidden) { result.push("hidden-revision-current"); }
      return result.join(" ");
    }
  },

  displayingInline: Em.computed.equal("viewMode", "inline"),
  displayingSideBySide: Em.computed.equal("viewMode", "side_by_side"),
  displayingSideBySideMarkdown: Em.computed.equal("viewMode", "side_by_side_markdown"),

  @computed('model.category_id_changes')
  previousCategory(changes) {
    if (changes) {
      var category = Discourse.Category.findById(changes["previous"]);
      return categoryBadgeHTML(category, { allowUncategorized: true });
    }
  },

  @computed('model.category_id_changes')
  currentCategory(changes) {
    if (changes) {
      var category = Discourse.Category.findById(changes["current"]);
      return categoryBadgeHTML(category, { allowUncategorized: true });
    }
  },

  @computed('model.wiki_changes')
  wikiDisabled(changes) {
    return changes && !changes['current'];
  },

  @computed('model.post_type_changes')
  postTypeDisabled(changes) {
    return (changes && changes['current'] !== this.site.get('post_types.moderator_action'));
  },

  @computed('viewMode', 'model.title_changes')
  titleDiff(viewMode) {
    if (viewMode === "side_by_side_markdown") { viewMode = "side_by_side"; }
    return this.get("model.title_changes." + viewMode);
  },

  @computed('viewMode', 'model.body_changes')
  bodyDiff(viewMode) {
    return this.get("model.body_changes." + viewMode);
  },

  actions: {
    loadFirstVersion: function() { this.refresh(this.get("model.post_id"), this.get("model.first_revision")); },
    loadPreviousVersion: function() { this.refresh(this.get("model.post_id"), this.get("model.previous_revision")); },
    loadNextVersion: function() { this.refresh(this.get("model.post_id"), this.get("model.next_revision")); },
    loadLastVersion: function() { this.refresh(this.get("model.post_id"), this.get("model.last_revision")); },

    hideVersion: function() { this.hide(this.get("model.post_id"), this.get("model.current_revision")); },
    showVersion: function() { this.show(this.get("model.post_id"), this.get("model.current_revision")); },

    displayInline: function() { this.set("viewMode", "inline"); },
    displaySideBySide: function() { this.set("viewMode", "side_by_side"); },
    displaySideBySideMarkdown: function() { this.set("viewMode", "side_by_side_markdown"); }
  }
});
