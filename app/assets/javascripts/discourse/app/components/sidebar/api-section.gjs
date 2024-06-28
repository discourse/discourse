import Component from "@glimmer/component";
import { service } from "@ember/service";
import Section from "./section";
import SectionLink from "./section-link";

export default class SidebarApiSection extends Component {
  @service sidebarState;

  get shouldDisplay() {
    return (
      !this.sidebarState.currentPanel.filterable ||
      this.sidebarState.filter.length === 0 ||
      this.filteredLinks.length > 0
    );
  }

  get filteredLinks() {
    if (!this.sidebarState.filter) {
      return this.args.section.links;
    }

    if (
      this.args.section.text
        .toLowerCase()
        .match(this.sidebarState.sanitizedFilter)
    ) {
      return this.args.section.links;
    }

    return this.args.section.links.filter((link) => {
      return (
        link.text
          .toString()
          .toLowerCase()
          .match(this.sidebarState.sanitizedFilter) ||
        link.keywords.navigation.some((keyword) =>
          keyword.match(this.sidebarState.filter)
        )
      );
    });
  }

  <template>
    {{#if this.shouldDisplay}}
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
      >
        {{#each this.filteredLinks key="name" as |link|}}
          <SectionLink
            @linkName={{link.name}}
            @linkClass={{link.classNames}}
            @route={{link.route}}
            @model={{link.model}}
            @query={{link.query}}
            @models={{link.models}}
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
            @currentWhen={{link.currentWhen}}
            @didInsert={{link.didInsert}}
            @willDestroy={{link.willDestroy}}
            @content={{link.text}}
            @contentComponent={{component
              link.contentComponent
              status=link.contentComponentArgs
            }}
          />
        {{/each}}
      </Section>
    {{/if}}
  </template>
}
