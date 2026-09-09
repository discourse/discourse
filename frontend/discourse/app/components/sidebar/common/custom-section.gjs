import Component from "@glimmer/component";
import { cached } from "@glimmer/tracking";
import { hash } from "@ember/helper";
import { getOwner } from "@ember/owner";
import { service } from "@ember/service";
import { findActiveLink } from "discourse/lib/sidebar/active-link";
import CommonCommunitySection from "discourse/lib/sidebar/common/community-section/section";
import Section from "discourse/lib/sidebar/section";
import AdminCommunitySection from "discourse/lib/sidebar/user/community-section/admin-section";
import { and, eq, not, or } from "discourse/truth-helpers";
import dReplaceEmoji from "discourse/ui-kit/helpers/d-replace-emoji";
import dDragAndDropSource from "discourse/ui-kit/modifiers/d-drag-and-drop-source";
import MoreSectionLink from "../more-section-link";
import MoreSectionLinks from "../more-section-links";
import SectionComponent from "../section";
import SectionLink from "../section-link";
import SectionLinkButton from "../section-link-button";

export default class SidebarCustomSection extends Component {
  @service capabilities;
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

  /**
   * Rows drag only where a drop may land, and never on touch-first devices,
   * where the press stays reserved for scrolling and the long-press link
   * preview. A machine with a mouse and a touch screen keeps dragging.
   */
  get linkDragEnabled() {
    return (
      Boolean(this.args.enableLinkDrop) &&
      this.section.canAcceptLinkDrop &&
      !this.capabilities.touchFirst
    );
  }

  get exactUrlMatch() {
    return this.section.links.find((link) => {
      return this.router.currentURL === link.value;
    });
  }

  <template>
    <SectionComponent
      @activeLink={{this.activeLink}}
      @collapsable={{@collapsable}}
      @expandWhenActive={{@expandActiveSection}}
      @headerActions={{this.section.headerActions}}
      @headerActionsIcon={{this.section.headerActionIcon}}
      @headerLinkText={{this.section.decoratedTitle}}
      @hideSectionHeader={{this.section.hideSectionHeader}}
      @indicatePublic={{this.section.indicatePublic}}
      @linkDropEnabled={{and @enableLinkDrop this.section.canAcceptLinkDrop}}
      @onLinkDrop={{this.section.dropLink}}
      @onLinkMove={{this.section.moveLink}}
      @sectionName={{this.section.slug}}
      as |linkDrop|
    >
      {{#each this.section.links as |link index|}}
        <SectionLink
          class={{if (eq linkDrop.linkDropIndex index) "is-link-drop-before"}}
          data-sidebar-custom-link="true"
          @badgeText={{link.badgeText}}
          @content={{dReplaceEmoji link.text}}
          @currentWhen={{link.currentWhen}}
          @exactUrlMatch={{this.exactUrlMatch}}
          @href={{or link.value link.href}}
          @linkName={{link.name}}
          @model={{link.model}}
          @models={{link.models}}
          @prefixType="icon"
          @prefixValue={{link.prefixValue}}
          @query={{link.query}}
          @route={{link.route}}
          @scrollIntoView={{and
            @scrollActiveLinkIntoView
            (eq link.name this.activeLink.name)
          }}
          @shouldDisplay={{link.shouldDisplay}}
          @suffixCSSClass={{link.suffixCSSClass}}
          @suffixType={{link.suffixType}}
          @suffixValue={{link.suffixValue}}
          @suppressNativeDrag={{this.linkDragEnabled}}
          @title={{link.title}}
          {{! Rows drag as registered sources; the native anchor drag is turned
              off with them, or the browser would start its own dead drag from
              the innermost anchor instead. }}
          {{dDragAndDropSource
            type="sidebar-link"
            data=(hash
              sectionId=@sectionData.id
              linkId=link.id
              public=@sectionData.public
              name=link.name
              value=link.value
              icon=link.prefixValue
            )
            effectAllowed="move"
            disabled=(not this.linkDragEnabled)
          }}
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
            @moreButtonAction={{this.section.moreSectionButtonAction}}
            @moreButtonIcon={{this.section.moreSectionButtonIcon}}
            @moreButtonText={{this.section.moreSectionButtonText}}
            @sectionLinks={{this.section.moreLinks}}
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
