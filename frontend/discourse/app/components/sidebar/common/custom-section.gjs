import Component from "@glimmer/component";
import { cached } from "@glimmer/tracking";
import { getOwner } from "@ember/owner";
import { service } from "@ember/service";
import { findActiveLink } from "discourse/lib/sidebar/active-link";
import CommonCommunitySection from "discourse/lib/sidebar/common/community-section/section";
import Section from "discourse/lib/sidebar/section";
import AdminCommunitySection from "discourse/lib/sidebar/user/community-section/admin-section";
import { and, eq, or } from "discourse/truth-helpers";
import dReplaceEmoji from "discourse/ui-kit/helpers/d-replace-emoji";
import MoreSectionLink from "../more-section-link";
import MoreSectionLinks from "../more-section-links";
import SectionComponent from "../section";
import SectionLink from "../section-link";
import SectionLinkButton from "../section-link-button";

export default class SidebarCustomSection extends Component {
  @service currentUser;
  @service navigationMenu;
  @service router;

  section = this.initialSection;

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

  @cached
  get activeLink() {
    return findActiveLink(
      [...this.section.links, ...(this.section.moreLinks || [])],
      this.router
    );
  }

  get exactUrlMatch() {
    return this.section.links.find((link) => {
      return this.router.currentURL === link.value;
    });
  }

  <template>
    <SectionComponent
      @sectionName={{this.section.slug}}
      @activeLink={{this.activeLink}}
      @expandWhenActive={{@expandActiveSection}}
      @headerLinkText={{this.section.decoratedTitle}}
      @indicatePublic={{this.section.indicatePublic}}
      @collapsable={{@collapsable}}
      @headerActions={{this.section.headerActions}}
      @headerActionsIcon={{this.section.headerActionIcon}}
      @hideSectionHeader={{this.section.hideSectionHeader}}
      @linkDropEnabled={{and @enableLinkDrop this.section.canAcceptLinkDrop}}
      @onLinkDrop={{this.section.dropLink}}
      class={{this.section.dragCss}}
      as |linkDrop|
    >
      {{#each this.section.links as |link index|}}
        <SectionLink
          data-sidebar-custom-link="true"
          class={{if (eq linkDrop.linkDropIndex index) "is-link-drop-before"}}
          @scrollIntoView={{and
            @scrollActiveLinkIntoView
            (eq link.name this.activeLink.name)
          }}
          @badgeText={{link.badgeText}}
          @content={{dReplaceEmoji link.text}}
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
          @exactUrlMatch={{this.exactUrlMatch}}
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
