import Component from "@glimmer/component";
import { concat, hash } from "@ember/helper";
import curryComponent from "ember-curry-component";
import { and, eq, not } from "discourse/truth-helpers";
import MoreSectionLink from "./more-section-link";
import MoreSectionLinks from "./more-section-links";
import Section from "./section";
import SectionLink from "./section-link";

export default class SidebarApiSection extends Component {
  get moreLinks() {
    return this.args.section.filteredMoreLinks ?? [];
  }

  get moreLinksAtStart() {
    return this.args.section.moreLinksPosition === "start";
  }

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

        {{#if this.moreLinksAtStart}}
          {{#if this.moreLinks}}
            {{#if @section.moreLinksInline}}
              {{#each this.moreLinks as |sectionLink|}}
                <MoreSectionLink
                  @sectionLink={{sectionLink}}
                  @scrollIntoView={{and
                    @scrollActiveLinkIntoView
                    (eq sectionLink.name @section.activeLink.name)
                  }}
                />
              {{/each}}
            {{else}}
              <MoreSectionLinks
                @sectionLinks={{this.moreLinks}}
                @scrollActiveLinkIntoView={{@scrollActiveLinkIntoView}}
                @identifier={{concat "sidebar-more-" @section.name}}
                @triggerText={{@section.moreLinksTriggerText}}
                @triggerPrefixType={{@section.moreLinksTriggerPrefixType}}
                @triggerPrefixValue={{@section.moreLinksTriggerPrefixValue}}
                @triggerSuffixType={{@section.moreLinksTriggerSuffixType}}
                @triggerSuffixValue={{@section.moreLinksTriggerSuffixValue}}
                @hoistActiveLink={{@section.moreLinksHoistActiveLink}}
              />
            {{/if}}
          {{/if}}
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
            @badgeText={{link.badgeText}}
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
            @contentComponent={{if
              link.contentComponent
              (curryComponent
                link.contentComponent (hash status=link.contentComponentArgs)
              )
            }}
            @suffixComponent={{link.suffixComponent}}
            @suffixArgs={{link.suffixArgs}}
            @scrollIntoView={{and
              @scrollActiveLinkIntoView
              (eq link.name @section.activeLink.name)
            }}
          />
        {{/each}}

        {{#unless this.moreLinksAtStart}}
          {{#if this.moreLinks}}
            {{#if @section.moreLinksInline}}
              {{#each this.moreLinks as |sectionLink|}}
                <MoreSectionLink
                  @sectionLink={{sectionLink}}
                  @scrollIntoView={{and
                    @scrollActiveLinkIntoView
                    (eq sectionLink.name @section.activeLink.name)
                  }}
                />
              {{/each}}
            {{else}}
              <MoreSectionLinks
                @sectionLinks={{this.moreLinks}}
                @scrollActiveLinkIntoView={{@scrollActiveLinkIntoView}}
                @identifier={{concat "sidebar-more-" @section.name}}
                @triggerText={{@section.moreLinksTriggerText}}
                @triggerPrefixType={{@section.moreLinksTriggerPrefixType}}
                @triggerPrefixValue={{@section.moreLinksTriggerPrefixValue}}
                @triggerSuffixType={{@section.moreLinksTriggerSuffixType}}
                @triggerSuffixValue={{@section.moreLinksTriggerSuffixValue}}
                @hoistActiveLink={{@section.moreLinksHoistActiveLink}}
              />
            {{/if}}
          {{/if}}
        {{/unless}}
      </Section>
    {{/if}}
  </template>
}
