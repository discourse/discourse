import ModalFunctionality from 'discourse/mixins/modal-functionality';
import { categoryLinkHTML } from 'discourse/helpers/category-link';
import computed from 'ember-addons/ember-computed-decorators';

export default Ember.Controller.extend(ModalFunctionality, {
  needs: ["topic"],

  loading: true,
  pinnedInCategoryCount: 0,
  pinnedGloballyCount: 0,
  bannerCount: 0,

  reset() {
    this.set("model.pinnedInCategoryUntil", null);
    this.set("model.pinnedGloballyUntil", null);
  },

  categoryLink: function() {
    return categoryLinkHTML(this.get("model.category"), { allowUncategorized: true });
  }.property("model.category"),

  unPinMessage: function() {
    let name = "topic.feature_topic.unpin";
    if (this.get("model.pinned_globally")) name += "_globally";
    if (moment(this.get("model.pinned_until")) > moment()) name += "_until";
    const until =  moment(this.get("model.pinned_until")).format("LL");

    return I18n.t(name, { categoryLink: this.get("categoryLink"), until: until });
  }.property("categoryLink", "model.{pinned_globally,pinned_until}"),

  @computed("categoryLink")
  pinMessage(categoryLink) {
    return I18n.t("topic.feature_topic.pin", { categoryLink });
  },

  alreadyPinnedMessage: function() {
    return I18n.t("topic.feature_topic.already_pinned", { categoryLink: this.get("categoryLink"), count: this.get("pinnedInCategoryCount") });
  }.property("categoryLink", "pinnedInCategoryCount"),

  @computed("parsedPinnedInCategoryUntil")
  pinDisabled(parsedPinnedInCategoryUntil) {
    return !this._isDateValid(parsedPinnedInCategoryUntil);
  },

  @computed("parsedPinnedGloballyUntil")
  pinGloballyDisabled(parsedPinnedGloballyUntil) {
    return !this._isDateValid(parsedPinnedGloballyUntil);
  },

  parsedPinnedInCategoryUntil: function() {
    return this._parseDate(this.get("model.pinnedInCategoryUntil"));
  }.property("model.pinnedInCategoryUntil"),

  parsedPinnedGloballyUntil: function() {
    return this._parseDate(this.get("model.pinnedGloballyUntil"));
  }.property("model.pinnedGloballyUntil"),

  _parseDate(date) {
    return moment(date, ["YYYY-MM-DD", "YYYY-MM-DD HH:mm"]);
  },

  _isDateValid(parsedDate) {
    return parsedDate.isValid() && parsedDate > moment();
  },

  onShow() {
    this.set("loading", true);

    return Discourse.ajax("/topics/feature_stats.json", {
      data: { category_id: this.get("model.category.id") }
    }).then(result => {
      if (result) {
        this.setProperties({
          pinnedInCategoryCount: result.pinned_in_category_count,
          pinnedGloballyCount: result.pinned_globally_count,
          bannerCount: result.banner_count,
        });
      }
    }).finally(() => this.set("loading", false));
  },

  _forwardAction(name) {
    this.get("controllers.topic").send(name);
    this.send("closeModal");
  },

  _confirmBeforePinning(count, name, action) {
    if (count < 4) {
      this._forwardAction(action);
    } else {
      this.send("hideModal");
      bootbox.confirm(
        I18n.t("topic.feature_topic.confirm_" + name, { count: count }),
        I18n.t("no_value"),
        I18n.t("yes_value"),
        confirmed => confirmed ? this._forwardAction(action) : this.send("reopenModal")
      );
    }
  },

  actions: {
    pin() { this._forwardAction("togglePinned"); },
    pinGlobally() { this._confirmBeforePinning(this.get("pinnedGloballyCount"), "pin_globally", "pinGlobally"); },
    unpin() { this._forwardAction("togglePinned"); },
    makeBanner() { this._forwardAction("makeBanner"); },
    removeBanner() { this._forwardAction("removeBanner"); },
  }

});
