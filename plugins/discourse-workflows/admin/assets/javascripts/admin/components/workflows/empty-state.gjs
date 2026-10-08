import DButton from "discourse/ui-kit/d-button";
import dEmoji from "discourse/ui-kit/helpers/d-emoji";

export default <template>
  <div class="workflows-empty-state">
    {{#if @emoji}}
      <span class="workflows-empty-state__icon">{{dEmoji @emoji}}</span>
    {{/if}}
    <h2 class="workflows-empty-state__title">{{@title}}</h2>
    <p class="workflows-empty-state__description">{{@description}}</p>
    {{#if @onAction}}
      <DButton
        class="btn-primary"
        @action={{@onAction}}
        @icon={{@buttonIcon}}
        @label={{@buttonLabel}}
        @translatedLabel={{@translatedButtonLabel}}
      />
    {{/if}}
  </div>
</template>
