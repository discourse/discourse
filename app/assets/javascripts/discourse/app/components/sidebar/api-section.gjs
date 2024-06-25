import Component from "@glimmer/component";
import { getOwner, setOwner } from "@ember/owner";
import { service } from "@ember/service";
import Section from "./section";
import SectionLink from "./section-link";

export default class SidebarApiSection extends Component {
  @service sidebarState;

  constructor() {
    super(...arguments);

    this.section = new this.args.sectionConfig();
    setOwner(this.section, getOwner(this));
  }

  get shouldDisplay() {
    return (
      !this.sidebarState.currentPanel.filterable ||
      this.sidebarState.filter.length === 0 ||
      this.filteredLinks.length > 0
    );
  }

  get filteredLinks() {
    if (!this.sidebarState.filter) {
      return this.section.links;
    }

    if (
      this.section.text.toLowerCase().match(this.sidebarState.sanitizedFilter)
    ) {
      return this.section.links;
    }

    return this.section.links.filter((link) => {
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
        @sectionName={{this.section.name}}
        @headerLinkText={{this.section.text}}
        @headerLinkTitle={{this.section.title}}
        @headerActionsIcon={{this.section.actionsIcon}}
        @headerActions={{this.section.actions}}
        @willDestroy={{this.section.willDestroy}}
        @collapsable={{@collapsable}}
        @displaySection={{this.section.displaySection}}
        @hideSectionHeader={{this.section.hideSectionHeader}}
        @collapsedByDefault={{this.section.collapsedByDefault}}
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
