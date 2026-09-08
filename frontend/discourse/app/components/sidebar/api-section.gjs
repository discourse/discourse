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
        @activeLink={{@section.activeLink}}
        @collapsable={{@collapsable}}
        @collapsedByDefault={{@section.collapsedByDefault}}
        @displaySection={{@section.displaySection}}
        @expandWhenActive={{@expandWhenActive}}
        @headerActions={{@section.actions}}
        @headerActionsIcon={{@section.actionsIcon}}
        @headerLinkText={{@section.text}}
        @headerLinkTitle={{@section.title}}
        @hideSectionHeader={{@section.hideSectionHeader}}
        @persistentActions={{@section.persistentActions}}
        @scrollActiveLinkIntoView={{@scrollActiveLinkIntoView}}
        @sectionName={{@section.name}}
        @willDestroy={{@section.willDestroy}}
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
                  @scrollIntoView={{and
                    @scrollActiveLinkIntoView
                    (eq sectionLink.name @section.activeLink.name)
                  }}
                  @sectionLink={{sectionLink}}
                />
              {{/each}}
            {{else}}
              <MoreSectionLinks
                @hoistActiveLink={{@section.moreLinksHoistActiveLink}}
                @identifier={{concat "sidebar-more-" @section.name}}
                @scrollActiveLinkIntoView={{@scrollActiveLinkIntoView}}
                @sectionLinks={{this.moreLinks}}
                @triggerPrefixType={{@section.moreLinksTriggerPrefixType}}
                @triggerPrefixValue={{@section.moreLinksTriggerPrefixValue}}
                @triggerSuffixType={{@section.moreLinksTriggerSuffixType}}
                @triggerSuffixValue={{@section.moreLinksTriggerSuffixValue}}
                @triggerText={{@section.moreLinksTriggerText}}
              />
            {{/if}}
          {{/if}}
        {{/if}}

        {{#each @section.filteredLinks key="name" as |link|}}
          <SectionLink
            @badgeText={{link.badgeText}}
            @content={{link.text}}
            @contentComponent={{if
              link.contentComponent
              (curryComponent
                link.contentComponent (hash status=link.contentComponentArgs)
              )
            }}
            @contentCSSClass={{link.contentCSSClass}}
            @currentWhen={{link.currentWhen}}
            @didInsert={{link.didInsert}}
            @hoverAction={{link.hoverAction}}
            @hoverTitle={{link.hoverTitle}}
            @hoverType={{link.hoverType}}
            @hoverValue={{link.hoverValue}}
            @href={{link.href}}
            @linkClass={{link.classNames}}
            @linkName={{link.name}}
            @model={{link.model}}
            @models={{link.models}}
            @prefixBadge={{link.prefixBadge}}
            @prefixColor={{link.prefixColor}}
            @prefixCSSClass={{link.prefixCSSClass}}
            @prefixType={{link.prefixType}}
            @prefixValue={{link.prefixValue}}
            @query={{link.query}}
            @route={{link.route}}
            @scrollIntoView={{and
              @scrollActiveLinkIntoView
              (eq link.name @section.activeLink.name)
            }}
            @suffixArgs={{link.suffixArgs}}
            @suffixComponent={{link.suffixComponent}}
            @suffixCSSClass={{link.suffixCSSClass}}
            @suffixType={{link.suffixType}}
            @suffixValue={{link.suffixValue}}
            @title={{link.title}}
            @willDestroy={{link.willDestroy}}
          />
        {{/each}}

        {{#unless this.moreLinksAtStart}}
          {{#if this.moreLinks}}
            {{#if @section.moreLinksInline}}
              {{#each this.moreLinks as |sectionLink|}}
                <MoreSectionLink
                  @scrollIntoView={{and
                    @scrollActiveLinkIntoView
                    (eq sectionLink.name @section.activeLink.name)
                  }}
                  @sectionLink={{sectionLink}}
                />
              {{/each}}
            {{else}}
              <MoreSectionLinks
                @hoistActiveLink={{@section.moreLinksHoistActiveLink}}
                @identifier={{concat "sidebar-more-" @section.name}}
                @scrollActiveLinkIntoView={{@scrollActiveLinkIntoView}}
                @sectionLinks={{this.moreLinks}}
                @triggerPrefixType={{@section.moreLinksTriggerPrefixType}}
                @triggerPrefixValue={{@section.moreLinksTriggerPrefixValue}}
                @triggerSuffixType={{@section.moreLinksTriggerSuffixType}}
                @triggerSuffixValue={{@section.moreLinksTriggerSuffixValue}}
                @triggerText={{@section.moreLinksTriggerText}}
              />
            {{/if}}
          {{/if}}
        {{/unless}}
      </Section>
    {{/if}}
  </template>
}
