import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import EmberObject, { action } from "@ember/object";
import { service } from "@ember/service";
import { trustHTML } from "@ember/template";
import { ajax } from "discourse/lib/ajax";
import DButton from "discourse/ui-kit/d-button";
import DConditionalLoadingSpinner from "discourse/ui-kit/d-conditional-loading-spinner";
import DFutureDateInput from "discourse/ui-kit/d-future-date-input";
import DModal from "discourse/ui-kit/d-modal";
import DPopupInputTip from "discourse/ui-kit/d-popup-input-tip";
import { categoryLinkHTML } from "discourse/ui-kit/helpers/d-category-link";
import dIcon from "discourse/ui-kit/helpers/d-icon";
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

  <template>
    <DModal
      class="feature-topic"
      @title={{i18n "topic.feature_topic.title"}}
      @closeModal={{@closeModal}}
    >
      <:body>
        {{#if @model.topic.pinned_at}}
          <div class="feature-section">
            <div class="desc">
              {{#if @model.topic.pinned_globally}}
                <p>
                  <DConditionalLoadingSpinner
                    @size="small"
                    @condition={{this.loading}}
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
                    @size="small"
                    @condition={{this.loading}}
                  >
                    {{trustHTML this.alreadyPinnedMessage}}
                  </DConditionalLoadingSpinner>
                </p>
                <p>{{i18n "topic.feature_topic.pin_note"}}</p>
              {{/if}}
              <p>{{trustHTML this.unPinMessage}}</p>
              <p><DButton
                  @action={{this.unpin}}
                  @icon="thumbtack"
                  @label="topic.feature.unpin"
                  class="btn-primary"
                /></p>
            </div>
          </div>
        {{else}}
          <div class="feature-section">
            <div class="desc">
              <p>
                <DConditionalLoadingSpinner
                  @size="small"
                  @condition={{this.loading}}
                >
                  {{trustHTML this.alreadyPinnedMessage}}
                </DConditionalLoadingSpinner>
              </p>
              <p>
                {{i18n "topic.feature_topic.pin_note"}}
              </p>
              {{#if this.site.mobileView}}
                <p>
                  {{trustHTML this.pinMessage}}
                </p>
                <p class="with-validation">
                  <DFutureDateInput
                    class="pin-until"
                    @clearable={{true}}
                    @input={{@model.topic.pinnedInCategoryUntil}}
                    @onChangeInput={{fn
                      (mut @model.topic.pinnedInCategoryUntil)
                    }}
                  />
                  <DPopupInputTip
                    @validation={{this.pinInCategoryValidation}}
                    @shownAt={{this.pinInCategoryTipShownAt}}
                  />
                </p>
              {{else}}
                <p class="with-validation">
                  {{trustHTML this.pinMessage}}
                  <span>
                    {{dIcon "far-clock"}}
                    <DFutureDateInput
                      class="pin-until"
                      @clearable={{true}}
                      @input={{@model.topic.pinnedInCategoryUntil}}
                      @onChangeInput={{fn
                        (mut @model.topic.pinnedInCategoryUntil)
                      }}
                    />
                    <DPopupInputTip
                      @validation={{this.pinInCategoryValidation}}
                      @shownAt={{this.pinInCategoryTipShownAt}}
                    />
                  </span>
                </p>
              {{/if}}
              <p>
                <DButton
                  @action={{this.pin}}
                  @icon="thumbtack"
                  @label="topic.feature.pin"
                  class="btn-primary"
                />
              </p>
            </div>
          </div>
          {{#if this.canPinGlobally}}
            <hr />
            <div class="feature-section">
              <div class="desc">
                <p>
                  <DConditionalLoadingSpinner
                    @size="small"
                    @condition={{this.loading}}
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
                <p>
                  {{i18n "topic.feature_topic.global_pin_note"}}
                </p>
                {{#if this.site.mobileView}}
                  <p>
                    {{i18n "topic.feature_topic.pin_globally"}}
                  </p>
                  <p class="with-validation">
                    <DFutureDateInput
                      class="pin-until"
                      @clearable={{true}}
                      @input={{@model.topic.pinnedGloballyUntil}}
                      @onChangeInput={{fn
                        (mut @model.topic.pinnedGloballyUntil)
                      }}
                    />
                    <DPopupInputTip
                      @validation={{this.pinGloballyValidation}}
                      @shownAt={{this.pinGloballyTipShownAt}}
                    />
                  </p>
                {{else}}
                  <p class="with-validation">
                    {{i18n "topic.feature_topic.pin_globally"}}
                    <span>
                      {{dIcon "far-clock"}}
                      <DFutureDateInput
                        class="pin-until"
                        @clearable={{true}}
                        @input={{@model.topic.pinnedGloballyUntil}}
                        @onChangeInput={{fn
                          (mut @model.topic.pinnedGloballyUntil)
                        }}
                      />
                      <DPopupInputTip
                        @validation={{this.pinGloballyValidation}}
                        @shownAt={{this.pinGloballyTipShownAt}}
                      />
                    </span>
                  </p>
                {{/if}}
                <p>
                  <DButton
                    @action={{this.pinGlobally}}
                    @icon="thumbtack"
                    @label="topic.feature.pin_globally"
                    class="btn-primary"
                  />
                </p>
              </div>
            </div>
          {{/if}}
        {{/if}}
        <hr />
        {{#if @model.topic.details.can_banner_topic}}
          <div class="feature-section">
            <div class="desc">
              <p>
                <DConditionalLoadingSpinner
                  @size="small"
                  @condition={{this.loading}}
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
                    @action={{this.removeBanner}}
                    @icon="thumbtack"
                    @label="topic.feature.remove_banner"
                    class="btn-primary"
                  />
                {{else}}
                  <DButton
                    @action={{this.makeBanner}}
                    @icon="thumbtack"
                    @label="topic.feature.make_banner"
                    class="btn-primary make-banner"
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
