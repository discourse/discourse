import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { trustHTML } from "@ember/template";
import ConditionalLoadingSpinner from "discourse/components/conditional-loading-spinner";
import DButton from "discourse/components/d-button";
import FutureDateInput from "discourse/components/future-date-input";
import PopupInputTip from "discourse/components/popup-input-tip";
import icon from "discourse/helpers/d-icon";
import { FORMAT } from "discourse/select-kit/components/future-date-input-selector";
import { i18n } from "discourse-i18n";

export const MAX_GLOBALLY_PINNED_TOPICS = 4;

export default class PinOptionSection extends Component {
  @service dialog;
  @service site;

  @tracked tipShownAt = false;

  get validation() {
    if (!this._isDateValid()) {
      return {
        failed: true,
        reason: i18n("topic.feature_topic.pin_validation"),
      };
    }
  }

  _isDateValid() {
    const parsed = moment(this.args.dateValue, FORMAT);
    return parsed.isValid() && parsed > moment();
  }

  @action
  pin() {
    if (!this._isDateValid()) {
      this.tipShownAt = Date.now();
      return;
    }

    if (this.args.confirmMessage) {
      this.dialog.yesNoConfirm({
        message: this.args.confirmMessage,
        didConfirm: () => this.args.onPin(),
      });
    } else {
      this.args.onPin();
    }
  }

  <template>
    <div class="feature-section">
      <div class="desc">
        {{#if @statsMessage}}
          <p>
            <ConditionalLoadingSpinner @size="small" @condition={{@loading}}>
              {{trustHTML @statsMessage}}
            </ConditionalLoadingSpinner>
          </p>
        {{/if}}

        <p>{{@noteMessage}}</p>

        {{#if this.site.mobileView}}
          <p>{{trustHTML @pinMessage}}</p>

          <p class="with-validation">
            <FutureDateInput
              class="pin-until"
              @clearable={{true}}
              @input={{@dateValue}}
              @onChangeInput={{@onDateChange}}
            />
            <PopupInputTip
              @validation={{this.validation}}
              @shownAt={{this.tipShownAt}}
            />
          </p>
        {{else}}
          <p class="with-validation">
            {{trustHTML @pinMessage}}
            <span>
              {{icon "far-clock"}}
              <FutureDateInput
                class="pin-until"
                @clearable={{true}}
                @input={{@dateValue}}
                @onChangeInput={{@onDateChange}}
              />
              <PopupInputTip
                @validation={{this.validation}}
                @shownAt={{this.tipShownAt}}
              />
            </span>
          </p>
        {{/if}}

        <p>
          <DButton
            @action={{this.pin}}
            @icon="thumbtack"
            @label={{@buttonLabel}}
            class="btn-primary"
          />
        </p>
      </div>
    </div>
  </template>
}
