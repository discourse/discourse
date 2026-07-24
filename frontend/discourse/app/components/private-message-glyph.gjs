import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

const PrivateMessageGlyph = <template>
  {{#if @shouldShow}}
    {{#if @href}}
      <a href={{@href}} title={{i18n @title}} aria-label={{i18n @ariaLabel}}>
        <span class="private-message-glyph-wrapper">
          {{dIcon "envelope" class="private-message-glyph"}}
        </span>
      </a>
    {{~else}}
      <span class="private-message-glyph-wrapper">
        {{dIcon "envelope" class="private-message-glyph"}}
      </span>
    {{~/if}}
  {{/if}}
</template>;

export default PrivateMessageGlyph;
