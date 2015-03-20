import ModalFunctionality from 'discourse/mixins/modal-functionality';
import ObjectController from 'discourse/controllers/object';
import { categoryLinkHTML } from 'discourse/helpers/category-link';

export default ObjectController.extend(ModalFunctionality, {
  needs: ["topic"],

  loading: true,
  pinnedInCategoryCount: 0,
  pinnedGloballyCount: 0,
  bannerCount: 0,

  categoryLink: function() {
    return categoryLinkHTML(this.get("category"), { allowUncategorized: true });
  }.property("category"),

  unPinMessage: function() {
    return this.get("pinned_globally") ?
           I18n.t("topic.feature_topic.unpin_globally") :
           I18n.t("topic.feature_topic.unpin", { categoryLink: this.get("categoryLink") });
  }.property("categoryLink", "pinned_globally"),

  pinMessage: function() {
    return I18n.t("topic.feature_topic.pin", { categoryLink: this.get("categoryLink") });
  }.property("categoryLink"),

  alreadyPinnedMessage: function() {
    return I18n.t("topic.feature_topic.already_pinned", { categoryLink: this.get("categoryLink"), count: this.get("pinnedInCategoryCount") });
  }.property("categoryLink", "pinnedInCategoryCount"),

  onShow() {
    this.set("loading", true);

    return Discourse.ajax("/topics/feature_stats.json", {
      data: { category_id: this.get("category.id") }
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
