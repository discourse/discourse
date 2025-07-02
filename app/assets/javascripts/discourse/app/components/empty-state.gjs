import { concat } from "@ember/helper";
import { or } from "truth-helpers";
import DButton from "discourse/components/d-button";
import icon from "discourse/helpers/d-icon";
import { i18n } from "discourse-i18n";

const EmptyState = <template>
  <div class="empty-state__container {{concat '--' @identifier}}">
    <div class="empty-state">
      {{#if @svgContent}}
        <div class="empty-state__image">
          {{@svgContent}}
        </div>
      {{/if}}

      {{#if @title}}
        <span data-test-title class="empty-state__title">{{i18n @title}}</span>
      {{/if}}

      {{#if @ctaLabel}}
        <div class="empty-state__cta">
          <DButton
            @action={{@ctaAction}}
            @href={{@ctaHref}}
            @route={{@ctaRoute}}
            @label={{@ctaLabel}}
            @icon={{@ctaIcon}}
            class="btn-primary"
          />
        </div>
      {{/if}}

      {{#if (or @tipText (has-block "tip"))}}
        <div class="empty-state__tip">
          {{#if @tipIcon}}
            {{icon @tipIcon}}
          {{/if}}
          {{#if (has-block "tip")}}
            {{yield to="tip"}}
          {{else}}
            {{@tipText}}
          {{/if}}
        </div>
      {{/if}}
    </div>
  </div>
</template>;

export default EmptyState;
