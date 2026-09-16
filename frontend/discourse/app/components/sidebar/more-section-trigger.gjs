import { eq, or } from "discourse/truth-helpers";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";
import SectionLinkPrefix from "./section-link-prefix";

const MoreSectionTrigger = <template>
  <button ...attributes class="sidebar-section-link sidebar-row" type="button">
    <SectionLinkPrefix
      @prefixCSSClass={{@prefixCSSClass}}
      @prefixType={{or @prefixType "icon"}}
      @prefixValue={{or @prefixValue "ellipsis-vertical"}}
    />

    <span class="sidebar-section-link-content-text">
      {{or @text (i18n "sidebar.more")}}
    </span>

    {{#if @suffixValue}}
      <span
        class={{dConcatClass
          "sidebar-section-link-suffix"
          @suffixType
          @suffixCSSClass
        }}
      >
        {{#if (eq @suffixType "icon")}}
          {{dIcon @suffixValue}}
        {{/if}}
      </span>
    {{/if}}
  </button>
</template>;

export default MoreSectionTrigger;
