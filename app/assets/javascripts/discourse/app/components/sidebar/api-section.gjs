import { and, eq } from "truth-helpers";
import Section from "./section";
import SectionLink from "./section-link";

const SidebarApiSection = <template>
  {{#if @section.filtered}}
    <Section
      @sectionName={{@section.name}}
      @headerLinkText={{@section.text}}
      @headerLinkTitle={{@section.title}}
      @headerActionsIcon={{@section.actionsIcon}}
      @headerActions={{@section.actions}}
      @willDestroy={{@section.willDestroy}}
      @collapsable={{@collapsable}}
      @displaySection={{@section.displaySection}}
      @hideSectionHeader={{@section.hideSectionHeader}}
      @collapsedByDefault={{@section.collapsedByDefault}}
      @activeLink={{@section.activeLink}}
      @expandWhenActive={{@expandWhenActive}}
      @scrollActiveLinkIntoView={{@scrollActiveLinkIntoView}}
      @level={{@section.level}}
    >
      {{#each @section.filteredLinks key="name" as |item|}}
        {{#if item.links}}
          <SidebarApiSection
            @section={{item}}
            @collapsable={{@collapsable}}
            @expandWhenActive={{@expandActiveSection}}
            @scrollActiveLinkIntoView={{@scrollActiveLinkIntoView}}
          />
        {{else}}
          <SectionLink
            @linkName={{item.name}}
            @linkClass={{item.classNames}}
            @route={{item.route}}
            @model={{item.model}}
            @query={{item.query}}
            @models={{item.models}}
            @currentWhen={{item.currentWhen}}
            @href={{item.href}}
            @title={{item.title}}
            @contentCSSClass={{item.contentCSSClass}}
            @prefixColor={{item.prefixColor}}
            @prefixBadge={{item.prefixBadge}}
            @prefixType={{item.prefixType}}
            @prefixValue={{item.prefixValue}}
            @prefixCSSClass={{item.prefixCSSClass}}
            @suffixType={{item.suffixType}}
            @suffixValue={{item.suffixValue}}
            @suffixCSSClass={{item.suffixCSSClass}}
            @hoverType={{item.hoverType}}
            @hoverValue={{item.hoverValue}}
            @hoverAction={{item.hoverAction}}
            @hoverTitle={{item.hoverTitle}}
            @didInsert={{item.didInsert}}
            @willDestroy={{item.willDestroy}}
            @content={{item.text}}
            @contentComponent={{component
              item.contentComponent
              status=item.contentComponentArgs
            }}
            @scrollIntoView={{and
              @scrollActiveLinkIntoView
              (eq item.name @section.activeLink.name)
            }}
          />
        {{/if}}
      {{/each}}
    </Section>
  {{/if}}
</template>;

export default SidebarApiSection;
