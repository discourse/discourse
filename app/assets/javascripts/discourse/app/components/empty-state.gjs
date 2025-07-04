import { concat } from "@ember/helper";
import { or } from "truth-helpers";
import DButton from "discourse/components/d-button";
import icon from "discourse/helpers/d-icon";

const EmptyState = <template>
  <div
    class="empty-state__container
      {{if @identifier (concat '--' @identifier)}}
      {{if @svgContent '--with-image' '--text-only'}}"
  >
    <div class="empty-state">
      {{#if @svgContent}}
        <div class="empty-state__image">
          {{@svgContent}}
        </div>
      {{/if}}

      {{#if @title}}
        <div data-test-title class="empty-state__title">{{@title}}</div>
      {{/if}}

      {{#if @body}}
        <div class="empty-state__body">
          <p data-test-body>{{@body}}</p>
        </div>
      {{/if}}

      {{#if @ctaLabel}}
        <div class="empty-state__cta">
          <DButton
            @action={{@ctaAction}}
            @href={{@ctaHref}}
            @route={{@ctaRoute}}
            @translatedLabel={{@ctaLabel}}
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
