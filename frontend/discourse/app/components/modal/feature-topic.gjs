import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { trustHTML } from "@ember/template";
import PinOptionSection, {
  MAX_GLOBALLY_PINNED_TOPICS,
} from "discourse/components/modal/feature-topic/pin-option-section";
import { ajax } from "discourse/lib/ajax";
import DButton from "discourse/ui-kit/d-button";
import DConditionalLoadingSpinner from "discourse/ui-kit/d-conditional-loading-spinner";
import DModal from "discourse/ui-kit/d-modal";
import { categoryLinkHTML } from "discourse/ui-kit/helpers/d-category-link";
import { i18n } from "discourse-i18n";

export default class FeatureTopic extends Component {
  @service currentUser;

  @tracked loading = true;
  @tracked pinnedInCategoryCount = 0;
  @tracked pinnedGloballyCount = 0;
  @tracked bannerCount = 0;

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

  get pinGloballyConfirmMessage() {
    if (this.pinnedGloballyCount >= MAX_GLOBALLY_PINNED_TOPICS) {
      return i18n("topic.feature_topic.confirm_pin_globally", {
        count: this.pinnedGloballyCount,
      });
    }
  }

  get pinGloballyStatsMessage() {
    if (this.pinnedGloballyCount) {
      return i18n("topic.feature_topic.already_pinned_globally", {
        count: this.pinnedGloballyCount,
      });
    }
    return i18n("topic.feature_topic.not_pinned_globally");
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

  @action
  pin() {
    this.args.model.togglePinned();
    this.args.closeModal();
  }

  @action
  pinGlobally() {
    this.args.model.pinGlobally();
    this.args.closeModal();
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

  <template>
    <DModal
      class="feature-topic"
      @closeModal={{@closeModal}}
      @title={{i18n "topic.feature_topic.title"}}
    >
      <:body>
        {{#if @model.topic.pinned_at}}
          <div class="feature-section">
            <div class="feature-section__description">
              {{#if @model.topic.pinned_globally}}
                <p>
                  <DConditionalLoadingSpinner
                    @condition={{this.loading}}
                    @size="small"
                  >
                    {{#if this.pinnedGloballyCount}}
                      {{trustHTML
                        (i18n
                          "topic.feature_topic.already_pinned_globally"
                          count=this.pinnedGloballyCount
                        )
                      }}
                    {{else}}
                      {{trustHTML
                        (i18n "topic.feature_topic.not_pinned_globally")
                      }}
                    {{/if}}
                  </DConditionalLoadingSpinner>
                </p>
                <p>{{i18n "topic.feature_topic.global_pin_note"}}</p>
              {{else}}
                <p>
                  <DConditionalLoadingSpinner
                    @condition={{this.loading}}
                    @size="small"
                  >
                    {{trustHTML this.alreadyPinnedMessage}}
                  </DConditionalLoadingSpinner>
                </p>
                <p>{{i18n "topic.feature_topic.pin_note"}}</p>
              {{/if}}
              <p>{{trustHTML this.unPinMessage}}</p>
              <p><DButton
                  class="btn-primary"
                  @action={{this.unpin}}
                  @icon="thumbtack"
                  @label="topic.feature.unpin"
                /></p>
            </div>
          </div>
        {{else}}
          <PinOptionSection
            @buttonLabel="topic.feature.pin"
            @dateValue={{@model.topic.pinnedInCategoryUntil}}
            @loading={{this.loading}}
            @noteMessage={{i18n "topic.feature_topic.pin_note"}}
            @onDateChange={{fn (mut @model.topic.pinnedInCategoryUntil)}}
            @onPin={{this.pin}}
            @pinMessage={{this.pinMessage}}
            @statsMessage={{this.alreadyPinnedMessage}}
          />
          {{#if this.canPinGlobally}}
            <hr />
            <PinOptionSection
              @buttonLabel="topic.feature.pin_globally"
              @confirmMessage={{this.pinGloballyConfirmMessage}}
              @dateValue={{@model.topic.pinnedGloballyUntil}}
              @loading={{this.loading}}
              @noteMessage={{i18n "topic.feature_topic.global_pin_note"}}
              @onDateChange={{fn (mut @model.topic.pinnedGloballyUntil)}}
              @onPin={{this.pinGlobally}}
              @pinMessage={{i18n "topic.feature_topic.pin_globally"}}
              @statsMessage={{this.pinGloballyStatsMessage}}
            />
          {{/if}}
        {{/if}}
        {{#if @model.topic.details.can_banner_topic}}
          <hr />
          <div class="feature-section">
            <div class="feature-section__description">
              <p>
                <DConditionalLoadingSpinner
                  @condition={{this.loading}}
                  @size="small"
                >
                  {{#if this.bannerCount}}
                    {{trustHTML (i18n "topic.feature_topic.banner_exists")}}
                  {{else}}
                    {{trustHTML (i18n "topic.feature_topic.no_banner_exists")}}
                  {{/if}}
                </DConditionalLoadingSpinner>
              </p>
              <p>
                {{i18n "topic.feature_topic.banner_note"}}
              </p>
              <p>
                {{#if @model.topic.isBanner}}
                  {{i18n "topic.feature_topic.remove_banner"}}
                {{else}}
                  {{i18n "topic.feature_topic.make_banner"}}
                {{/if}}
              </p>
              <p>
                {{#if @model.topic.isBanner}}
                  <DButton
                    class="btn-primary"
                    @action={{this.removeBanner}}
                    @icon="thumbtack"
                    @label="topic.feature.remove_banner"
                  />
                {{else}}
                  <DButton
                    class="btn-primary make-banner"
                    @action={{this.makeBanner}}
                    @icon="thumbtack"
                    @label="topic.feature.make_banner"
                  />
                {{/if}}
              </p>
            </div>
          </div>
        {{/if}}
      </:body>
    </DModal>
  </template>
}
