import { or } from "discourse/truth-helpers";
import dReplaceEmoji from "discourse/ui-kit/helpers/d-replace-emoji";
import SectionLink from "./section-link";

const SidebarMoreSectionLink = <template>
  <SectionLink
    @badgeText={{@sectionLink.badgeText}}
    @content={{dReplaceEmoji @sectionLink.text}}
    @currentWhen={{@sectionLink.currentWhen}}
    @href={{or @sectionLink.href @sectionLink.value}}
    @linkName={{@sectionLink.name}}
    @model={{@sectionLink.model}}
    @models={{@sectionLink.models}}
    @prefixType="icon"
    @prefixValue={{@sectionLink.prefixValue}}
    @query={{@sectionLink.query}}
    @route={{@sectionLink.route}}
    @shouldDisplay={{@sectionLink.shouldDisplay}}
    @suffixCSSClass={{@sectionLink.suffixCSSClass}}
    @suffixType={{@sectionLink.suffixType}}
    @suffixValue={{@sectionLink.suffixValue}}
    @title={{@sectionLink.title}}
    @toggleNavigationMenu={{@toggleNavigationMenu}}
    ...attributes
  />
</template>;

export default SidebarMoreSectionLink;
