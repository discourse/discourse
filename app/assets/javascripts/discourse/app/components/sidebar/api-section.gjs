import Component from "@glimmer/component";
import { service } from "@ember/service";
import { and, eq, not } from "truth-helpers";
import MoreSectionLink from "./more-section-link";
import MoreSectionLinks from "./more-section-links";
import Section from "./section";
import SectionLink from "./section-link";
import SectionLinkButton from "./section-link-button";

export default class SidebarApiSection extends Component {
  @service navigationMenu;

  <template>
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
      >
        {{#if
          (and @section.emptyStateComponent (not @section.filteredLinks.length))
        }}
          <@section.emptyStateComponent />
        {{/if}}

        {{#each @section.filteredLinks key="name" as |link|}}
          <SectionLink
            @linkName={{link.name}}
            @linkClass={{link.classNames}}
            @route={{link.route}}
            @model={{link.model}}
            @query={{link.query}}
            @models={{link.models}}
            @currentWhen={{link.currentWhen}}
            @href={{link.href}}
            @title={{link.title}}
            @contentCSSClass={{link.contentCSSClass}}
            @prefixColor={{link.prefixColor}}
            @prefixBadge={{link.prefixBadge}}
            @prefixType={{link.prefixType}}
            @prefixValue={{link.prefixValue}}
            @prefixCSSClass={{link.prefixCSSClass}}
            @suffixType={{link.suffixType}}
            @suffixValue={{link.suffixValue}}
            @suffixCSSClass={{link.suffixCSSClass}}
            @hoverType={{link.hoverType}}
            @hoverValue={{link.hoverValue}}
            @hoverAction={{link.hoverAction}}
            @hoverTitle={{link.hoverTitle}}
            @didInsert={{link.didInsert}}
            @willDestroy={{link.willDestroy}}
            @content={{link.text}}
            @contentComponent={{component
              link.contentComponent
              status=link.contentComponentArgs
            }}
            @scrollIntoView={{and
              @scrollActiveLinkIntoView
              (eq link.name @section.activeLink.name)
            }}
          />
        {{/each}}

        {{#if @section.moreLinks}}
          {{#if this.navigationMenu.isDesktopDropdownMode}}
            {{#each @section.moreLinks as |sectionLink|}}
              <MoreSectionLink @sectionLink={{sectionLink}} />
            {{/each}}

            {{#if @section.moreSectionButtonAction}}
              <SectionLinkButton
                @action={{@section.moreSectionButtonAction}}
                @icon={{@section.moreSectionButtonIcon}}
                @text={{@section.moreSectionButtonText}}
              />
            {{/if}}
          {{else}}
            <MoreSectionLinks
              @sectionLinks={{@section.moreLinks}}
              @moreText={{@section.moreSectionText}}
              @moreIcon={{@section.moreSectionIcon}}
              @moreButtonAction={{@section.moreSectionButtonAction}}
              @moreButtonText={{@section.moreSectionButtonText}}
              @moreButtonIcon={{@section.moreSectionButtonIcon}}
              @toggleNavigationMenu={{@toggleNavigationMenu}}
            />
          {{/if}}
        {{else if @section.moreSectionButtonAction}}
          <SectionLinkButton
            @action={{@section.moreSectionButtonAction}}
            @icon={{@section.moreSectionButtonIcon}}
            @text={{@section.moreSectionButtonText}}
          />
        {{/if}}
      </Section>
    {{/if}}
  </template>
}
