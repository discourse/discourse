import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { getOwner } from "@ember/owner";
import { service } from "@ember/service";
import { or } from "truth-helpers";
import replaceEmoji from "discourse/helpers/replace-emoji";
import CommonCommunitySection from "discourse/lib/sidebar/common/community-section/section";
import Section from "discourse/lib/sidebar/section";
import AdminCommunitySection from "discourse/lib/sidebar/user/community-section/admin-section";
import MoreSectionLink from "../more-section-link";
import MoreSectionLinks from "../more-section-links";
import SectionComponent from "../section";
import SectionLink from "../section-link";
import SectionLinkButton from "../section-link-button";

export default class SidebarCustomSection extends Component {
  @service currentUser;
  @service navigationMenu;
  @service site;
  @service siteSettings;

  @tracked section = this.initialSection;

  willDestroy() {
    super.willDestroy();
    this.section.teardown?.();
  }

  get initialSection() {
    const opts = {
      section: this.args.sectionData,
      owner: getOwner(this),
    };

    if (this.args.sectionData.section_type !== "community") {
      return new Section(opts);
    } else if (this.currentUser?.admin) {
      return new AdminCommunitySection(opts);
    } else {
      return new CommonCommunitySection(opts);
    }
  }

  <template>
    <SectionComponent
      @sectionName={{this.section.slug}}
      @headerLinkText={{this.section.decoratedTitle}}
      @indicatePublic={{this.section.indicatePublic}}
      @collapsable={{@collapsable}}
      @headerActions={{this.section.headerActions}}
      @headerActionsIcon={{this.section.headerActionIcon}}
      @hideSectionHeader={{this.section.hideSectionHeader}}
      class={{this.section.dragCss}}
    >
      {{#each this.section.links as |link|}}
        <SectionLink
          @badgeText={{link.badgeText}}
          @content={{replaceEmoji link.text}}
          @currentWhen={{link.currentWhen}}
          @href={{or link.value link.href}}
          @linkClass={{link.linkDragCss}}
          @linkName={{link.name}}
          @model={{link.model}}
          @models={{link.models}}
          @prefixType="icon"
          @prefixValue={{link.prefixValue}}
          @query={{link.query}}
          @route={{link.route}}
          @shouldDisplay={{link.shouldDisplay}}
          @suffixCSSClass={{link.suffixCSSClass}}
          @suffixType={{link.suffixType}}
          @suffixValue={{link.suffixValue}}
          @title={{link.title}}
        />
      {{/each}}

      {{#if this.section.moreLinks}}
        {{#if this.navigationMenu.isDesktopDropdownMode}}
          {{#each this.section.moreLinks as |sectionLink|}}
            <MoreSectionLink @sectionLink={{sectionLink}} />
          {{/each}}

          {{#if this.section.moreSectionButtonAction}}
            <SectionLinkButton
              @action={{this.section.moreSectionButtonAction}}
              @icon={{this.section.moreSectionButtonIcon}}
              @text={{this.section.moreSectionButtonText}}
            />
          {{/if}}
        {{else}}
          <MoreSectionLinks
            @sectionLinks={{this.section.moreLinks}}
            @moreButtonAction={{this.section.moreSectionButtonAction}}
            @moreButtonText={{this.section.moreSectionButtonText}}
            @moreButtonIcon={{this.section.moreSectionButtonIcon}}
            @toggleNavigationMenu={{@toggleNavigationMenu}}
          />
        {{/if}}
      {{else if this.section.moreSectionButtonAction}}
        <SectionLinkButton
          @action={{this.section.moreSectionButtonAction}}
          @icon={{this.section.moreSectionButtonIcon}}
          @text={{this.section.moreSectionButtonText}}
        />
      {{/if}}
    </SectionComponent>
  </template>
}
