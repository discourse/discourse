import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import PinOptionSection, {
  MAX_GLOBALLY_PINNED_TOPICS,
} from "discourse/components/modal/feature-topic/pin-option-section";
import { categoryLinkHTML } from "discourse/helpers/category-link";
import { ajax } from "discourse/lib/ajax";
import { i18n } from "discourse-i18n";

export default class BulkPinOptions extends Component {
  @service currentUser;

  @tracked loading = true;
  @tracked pinnedInCategoryCount = 0;
  @tracked pinnedGloballyCount = 0;
  @tracked pinnedInCategoryUntil = null;
  @tracked pinnedGloballyUntil = null;

  constructor() {
    super(...arguments);
    this.loadFeatureStats();
  }

  get categoryLink() {
    if (this.args.category) {
      return categoryLinkHTML(this.args.category, { allowUncategorized: true });
    }
  }

  get pinnedInCategoryStatsMessage() {
    if (!this.args.category) {
      return;
    }

    const key =
      this.pinnedInCategoryCount === 0
        ? "topic.feature_topic.not_pinned"
        : "topic.feature_topic.already_pinned";

    return i18n(key, {
      categoryLink: this.categoryLink,
      count: this.pinnedInCategoryCount,
    });
  }

  get pinGloballyConfirmMessage() {
    if (this.pinnedGloballyCount >= MAX_GLOBALLY_PINNED_TOPICS) {
      return i18n("topic.feature_topic.confirm_pin_globally", {
        count: this.pinnedGloballyCount,
      });
    }
  }

  get pinnedGloballyStatsMessage() {
    if (this.pinnedGloballyCount) {
      return i18n("topic.feature_topic.already_pinned_globally", {
        count: this.pinnedGloballyCount,
      });
    }
    return i18n("topic.feature_topic.not_pinned_globally");
  }

  async loadFeatureStats() {
    try {
      const data = {};

      if (this.args.category) {
        data.category_id = this.args.category.id;
      }

      const result = await ajax("/topics/feature_stats.json", { data });

      if (result) {
        this.pinnedInCategoryCount = result.pinned_in_category_count;
        this.pinnedGloballyCount = result.pinned_globally_count;
      }
    } finally {
      this.loading = false;
    }
  }

  @action
  pinInCategory() {
    this.args.onPin({
      pinned_globally: false,
      pinned_until: this.pinnedInCategoryUntil,
    });
  }

  @action
  pinGlobally() {
    this.args.onPin({
      pinned_globally: true,
      pinned_until: this.pinnedGloballyUntil,
    });
  }

  @action
  updatePinnedInCategoryUntil(date) {
    this.pinnedInCategoryUntil = date;
  }

  @action
  updatePinnedGloballyUntil(date) {
    this.pinnedGloballyUntil = date;
  }

  <template>
    <PinOptionSection
      @statsMessage={{this.pinnedInCategoryStatsMessage}}
      @loading={{this.loading}}
      @noteMessage={{i18n "topic.bulk_feature_topic.pin_note"}}
      @pinMessage={{i18n "topic.bulk_feature_topic.pin"}}
      @buttonLabel="topic.bulk_feature_topic.pin_button"
      @onPin={{this.pinInCategory}}
      @dateValue={{this.pinnedInCategoryUntil}}
      @onDateChange={{this.updatePinnedInCategoryUntil}}
    />

    {{#if this.currentUser.canManageTopic}}
      <hr />
      <PinOptionSection
        @statsMessage={{this.pinnedGloballyStatsMessage}}
        @loading={{this.loading}}
        @noteMessage={{i18n "topic.bulk_feature_topic.pin_note"}}
        @pinMessage={{i18n "topic.bulk_feature_topic.pin_globally"}}
        @buttonLabel="topic.bulk_feature_topic.pin_globally_button"
        @onPin={{this.pinGlobally}}
        @dateValue={{this.pinnedGloballyUntil}}
        @onDateChange={{this.updatePinnedGloballyUntil}}
        @confirmMessage={{this.pinGloballyConfirmMessage}}
      />
    {{/if}}
  </template>
}
