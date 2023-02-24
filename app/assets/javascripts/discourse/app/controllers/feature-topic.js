import { inject as controller } from "@ember/controller";
import EmberObject from "@ember/object";
import I18n from "I18n";
import Modal from "discourse/controllers/modal";
import { ajax } from "discourse/lib/ajax";
import { categoryLinkHTML } from "discourse/helpers/category-link";
import discourseComputed from "discourse-common/utils/decorators";
import { inject as service } from "@ember/service";

export default Modal.extend({
  topicController: controller("topic"),
  dialog: service(),

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

  @discourseComputed("model.category")
  categoryLink(category) {
    return categoryLinkHTML(category, { allowUncategorized: true });
  },

  @discourseComputed(
    "categoryLink",
    "model.pinned_globally",
    "model.pinned_until"
  )
  unPinMessage(categoryLink, pinnedGlobally, pinnedUntil) {
    let name = "topic.feature_topic.unpin";
    if (pinnedGlobally) {
      name += "_globally";
    }
    if (moment(pinnedUntil) > moment()) {
      name += "_until";
    }
    const until = moment(pinnedUntil).format("LL");

    return I18n.t(name, { categoryLink, until });
  },

  @discourseComputed("model.details.can_pin_unpin_topic")
  canPinGlobally(canPinUnpinTopic) {
    return this.currentUser.canManageTopic && canPinUnpinTopic;
  },

  @discourseComputed("categoryLink")
  pinMessage(categoryLink) {
    return I18n.t("topic.feature_topic.pin", { categoryLink });
  },

  @discourseComputed("categoryLink", "pinnedInCategoryCount")
  alreadyPinnedMessage(categoryLink, count) {
    const key =
      count === 0
        ? "topic.feature_topic.not_pinned"
        : "topic.feature_topic.already_pinned";
    return I18n.t(key, { categoryLink, count });
  },

  @discourseComputed("parsedPinnedInCategoryUntil")
  pinDisabled(parsedPinnedInCategoryUntil) {
    return !this._isDateValid(parsedPinnedInCategoryUntil);
  },

  @discourseComputed("parsedPinnedGloballyUntil")
  pinGloballyDisabled(parsedPinnedGloballyUntil) {
    return !this._isDateValid(parsedPinnedGloballyUntil);
  },

  @discourseComputed("model.pinnedInCategoryUntil")
  parsedPinnedInCategoryUntil(pinnedInCategoryUntil) {
    return this._parseDate(pinnedInCategoryUntil);
  },

  @discourseComputed("model.pinnedGloballyUntil")
  parsedPinnedGloballyUntil(pinnedGloballyUntil) {
    return this._parseDate(pinnedGloballyUntil);
  },

  @discourseComputed("pinDisabled")
  pinInCategoryValidation(pinDisabled) {
    if (pinDisabled) {
      return EmberObject.create({
        failed: true,
        reason: I18n.t("topic.feature_topic.pin_validation"),
      });
    }
  },

  @discourseComputed("pinGloballyDisabled")
  pinGloballyValidation(pinGloballyDisabled) {
    if (pinGloballyDisabled) {
      return EmberObject.create({
        failed: true,
        reason: I18n.t("topic.feature_topic.pin_validation"),
      });
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

    return ajax("/topics/feature_stats.json", {
      data: { category_id: this.get("model.category.id") },
    })
      .then((result) => {
        if (result) {
          this.setProperties({
            pinnedInCategoryCount: result.pinned_in_category_count,
            pinnedGloballyCount: result.pinned_globally_count,
            bannerCount: result.banner_count,
          });
        }
      })
      .finally(() => this.set("loading", false));
  },

  _forwardAction(name) {
    this.topicController.send(name);
    this.send("closeModal");
  },

  _confirmBeforePinningGlobally() {
    const count = this.pinnedGloballyCount;

    if (count < 4) {
      this._forwardAction("pinGlobally");
    } else {
      this.send("hideModal");
      this.dialog.yesNoConfirm({
        message: I18n.t("topic.feature_topic.confirm_pin_globally", { count }),
        didConfirm: () => this._forwardAction("pinGlobally"),
        didCancel: () => this.send("reopenModal"),
      });
    }
  },

  actions: {
    pin() {
      if (this.pinDisabled) {
        this.set("pinInCategoryTipShownAt", Date.now());
      } else {
        this._forwardAction("togglePinned");
      }
    },

    pinGlobally() {
      if (this.pinGloballyDisabled) {
        this.set("pinGloballyTipShownAt", Date.now());
      } else {
        this._confirmBeforePinningGlobally();
      }
    },

    unpin() {
      this._forwardAction("togglePinned");
    },
    makeBanner() {
      this._forwardAction("makeBanner");
    },
    removeBanner() {
      this._forwardAction("removeBanner");
    },
  },
});
