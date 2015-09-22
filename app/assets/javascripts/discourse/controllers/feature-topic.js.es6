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
    this.setProperties({
      "model.pinnedInCategoryUntil": null,
      "model.pinnedGloballyUntil": null,
      pinInCategoryTipShownAt: false,
      pinGloballyTipShownAt: false,
    });
  },

  @computed("model.category")
  categoryLink(category) {
    return categoryLinkHTML(category, { allowUncategorized: true });
  },

  @computed("categoryLink", "model.pinned_globally", "model.pinned_until")
  unPinMessage(categoryLink, pinnedGlobally, pinnedUntil) {
    let name = "topic.feature_topic.unpin";
    if (pinnedGlobally) name += "_globally";
    if (moment(pinnedUntil) > moment()) name += "_until";
    const until =  moment(pinnedUntil).format("LL");

    return I18n.t(name, { categoryLink, until });
  },

  @computed("categoryLink")
  pinMessage(categoryLink) {
    return I18n.t("topic.feature_topic.pin", { categoryLink });
  },

  @computed("categoryLink", "pinnedInCategoryCount")
  alreadyPinnedMessage(categoryLink, count) {
    return I18n.t("topic.feature_topic.already_pinned", { categoryLink, count });
  },

  @computed("parsedPinnedInCategoryUntil")
  pinDisabled(parsedPinnedInCategoryUntil) {
    return !this._isDateValid(parsedPinnedInCategoryUntil);
  },

  @computed("parsedPinnedGloballyUntil")
  pinGloballyDisabled(parsedPinnedGloballyUntil) {
    return !this._isDateValid(parsedPinnedGloballyUntil);
  },

  @computed("model.pinnedInCategoryUntil")
  parsedPinnedInCategoryUntil(pinnedInCategoryUntil) {
    return this._parseDate(pinnedInCategoryUntil);
  },

  @computed("model.pinnedGloballyUntil")
  parsedPinnedGloballyUntil(pinnedGloballyUntil) {
    return this._parseDate(pinnedGloballyUntil);
  },

  @computed("pinDisabled")
  pinInCategoryValidation(pinDisabled) {
    if (pinDisabled) {
      return Discourse.InputValidation.create({ failed: true, reason: I18n.t("topic.feature_topic.pin_validation") });
    }
  },

  @computed("pinGloballyDisabled")
  pinGloballyValidation(pinGloballyDisabled) {
    if (pinGloballyDisabled) {
      return Discourse.InputValidation.create({ failed: true, reason: I18n.t("topic.feature_topic.pin_validation") });
    }
  },

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
        I18n.t("topic.feature_topic.confirm_" + name, { count }),
        I18n.t("no_value"),
        I18n.t("yes_value"),
        confirmed => confirmed ? this._forwardAction(action) : this.send("reopenModal")
      );
    }
  },

  actions: {
    pin() {
      if (this.get("pinDisabled")) {
        this.set("pinInCategoryTipShownAt", Date.now());
      } else {
        this._forwardAction("togglePinned");
      }
    },

    pinGlobally() {
      if (this.get("pinGloballyDisabled")) {
        this.set("pinGloballyTipShownAt", Date.now());
      } else {
        this._confirmBeforePinning(this.get("pinnedGloballyCount"), "pin_globally", "pinGlobally");
      }
    },


    unpin() { this._forwardAction("togglePinned"); },
    makeBanner() { this._forwardAction("makeBanner"); },
    removeBanner() { this._forwardAction("removeBanner"); },
  }

});
