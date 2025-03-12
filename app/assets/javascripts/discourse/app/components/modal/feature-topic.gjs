import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import EmberObject, { action } from "@ember/object";
import { service } from "@ember/service";
import { categoryLinkHTML } from "discourse/helpers/category-link";
import { ajax } from "discourse/lib/ajax";
import { i18n } from "discourse-i18n";

export default class FeatureTopic extends Component {
  @service currentUser;
  @service dialog;

  @tracked loading = true;
  @tracked pinnedInCategoryCount = 0;
  @tracked pinnedGloballyCount = 0;
  @tracked bannerCount = 0;
  @tracked pinInCategoryTipShownAt = false;
  @tracked pinGloballyTipShownAt = false;

  constructor() {
    super(...arguments);
    this.loadFeatureStats();
  }

  get categoryLink() {
    return categoryLinkHTML(this.args.model.topic.category, {
      allowUncategorized: true,
    });
  }

  get unPinMessage() {
    let name = "topic.feature_topic.unpin";
    if (this.args.model.topic.pinned_globally) {
      name += "_globally";
    }
    if (moment(this.args.model.topic.pinned_until) > moment()) {
      name += "_until";
    }
    const until = moment(this.args.model.topic.pinned_until).format("LL");
    return i18n(name, { categoryLink: this.categoryLink, until });
  }

  get canPinGlobally() {
    return (
      this.currentUser.canManageTopic &&
      this.args.model.topic.details.can_pin_unpin_topic
    );
  }

  get pinMessage() {
    return i18n("topic.feature_topic.pin", {
      categoryLink: this.categoryLink,
    });
  }

  get alreadyPinnedMessage() {
    const key =
      this.pinnedInCategoryCount === 0
        ? "topic.feature_topic.not_pinned"
        : "topic.feature_topic.already_pinned";
    return i18n(key, {
      categoryLink: this.categoryLink,
      count: this.pinnedInCategoryCount,
    });
  }

  get pinDisabled() {
    return !this._isDateValid(this.parsedPinnedInCategoryUntil);
  }

  get pinGloballyDisabled() {
    return !this._isDateValid(this.parsedPinnedGloballyUntil);
  }

  get parsedPinnedInCategoryUntil() {
    return this._parseDate(this.args.model.topic.pinnedInCategoryUntil);
  }

  get parsedPinnedGloballyUntil() {
    return this._parseDate(this.args.model.topic.pinnedGloballyUntil);
  }

  get pinInCategoryValidation() {
    if (this.pinDisabled) {
      return EmberObject.create({
        failed: true,
        reason: i18n("topic.feature_topic.pin_validation"),
      });
    }
  }

  get pinGloballyValidation() {
    if (this.pinGloballyDisabled) {
      return EmberObject.create({
        failed: true,
        reason: i18n("topic.feature_topic.pin_validation"),
      });
    }
  }

  _parseDate(date) {
    return moment(date, ["YYYY-MM-DD", "YYYY-MM-DD HH:mm"]);
  }

  _isDateValid(parsedDate) {
    return parsedDate.isValid() && parsedDate > moment();
  }

  @action
  async loadFeatureStats() {
    try {
      this.loading = true;
      const result = await ajax("/topics/feature_stats.json", {
        data: { category_id: this.args.model.topic.category.id },
      });

      if (result) {
        this.pinnedInCategoryCount = result.pinned_in_category_count;
        this.pinnedGloballyCount = result.pinned_globally_count;
        this.bannerCount = result.banner_count;
      }
    } finally {
      this.loading = false;
    }
  }

  async _confirmBeforePinningGlobally() {
    if (this.pinnedGloballyCount < 4) {
      this.args.model.pinGlobally();
      this.args.closeModal();
    } else {
      this.dialog.yesNoConfirm({
        message: i18n("topic.feature_topic.confirm_pin_globally", {
          count: this.pinnedGloballyCount,
        }),
        didConfirm: () => {
          this.args.model.pinGlobally();
          this.args.closeModal();
        },
      });
    }
  }

  @action
  pin() {
    if (this.pinDisabled) {
      this.pinInCategoryTipShownAt = Date.now();
    } else {
      this.args.model.togglePinned();
      this.args.closeModal();
    }
  }

  @action
  pinGlobally() {
    if (this.pinGloballyDisabled) {
      this.pinGloballyTipShownAt = Date.now();
    } else {
      this._confirmBeforePinningGlobally();
    }
  }

  @action
  unpin() {
    this.args.model.togglePinned();
    this.args.closeModal();
  }

  @action
  makeBanner() {
    this.args.model.makeBanner();
    this.args.closeModal();
  }

  @action
  removeBanner() {
    this.args.model.removeBanner();
    this.args.closeModal();
  }
}
