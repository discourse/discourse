import Component from "@glimmer/component";
import { cached } from "@glimmer/tracking";
import { array, hash } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import SidebarEditNavigationMenuTagsModal from "discourse/components/sidebar/edit-navigation-menu/tags-modal";
import { findActiveLink } from "discourse/lib/sidebar/active-link";
import { hasDefaultSidebarTags } from "discourse/lib/sidebar/helpers";
import PMTagSectionLink from "discourse/lib/sidebar/user/tags-section/pm-tag-section-link";
import TagSectionLink from "discourse/lib/sidebar/user/tags-section/tag-section-link";
import { and, eq } from "discourse/truth-helpers";
import { i18n } from "discourse-i18n";
import AllTagsSectionLink from "../common/all-tags-section-link";
import Section from "../section";
import SectionLink from "../section-link";

export default class SidebarUserTagsSection extends Component {
  @service router;
  @service currentUser;
  @service modal;
  @service site;
  @service siteSettings;
  @service topicTrackingState;

  constructor() {
    super(...arguments);

    this.callbackId = this.topicTrackingState.onStateChange(() => {
      this.sectionLinks.forEach((sectionLink) => {
        if (sectionLink.refreshCounts) {
          sectionLink.refreshCounts();
        }
      });
    });
  }

  willDestroy() {
    super.willDestroy(...arguments);
    this.topicTrackingState.offStateChange(this.callbackId);
  }

  @cached
  get activeLink() {
    return findActiveLink(this.sectionLinks, this.router);
  }

  @cached
  get sectionLinks() {
    const links = [];
    let tags;

    if (this.currentUser.sidebarTags.length > 0) {
      tags = this.currentUser.sidebarTags;
    } else {
      tags = this.site.navigation_menu_site_top_tags || [];
    }

    for (const tag of tags) {
      if (tag.pm_only) {
        links.push(
          new PMTagSectionLink({
            tag,
            currentUser: this.currentUser,
          })
        );
      } else {
        links.push(
          new TagSectionLink({
            tag,
            topicTrackingState: this.topicTrackingState,
            currentUser: this.currentUser,
          })
        );
      }
    }

    return links;
  }

  get shouldDisplayDefaultConfig() {
    return this.currentUser.admin && !this.hasDefaultSidebarTags;
  }

  get hasDefaultSidebarTags() {
    return hasDefaultSidebarTags(this.siteSettings);
  }

  @action
  showModal() {
    this.modal.show(SidebarEditNavigationMenuTagsModal);
  }

  <template>
    <Section
      @activeLink={{this.activeLink}}
      @collapsable={{@collapsable}}
      @expandWhenActive={{@expandActiveSection}}
      @headerActions={{array
        (hash
          action=this.showModal
          title=(i18n "sidebar.sections.tags.header_action_title")
        )
      }}
      @headerActionsIcon="pencil"
      @headerLinkText={{i18n "sidebar.sections.tags.header_link_text"}}
      @sectionName="tags"
    >
      {{#each this.sectionLinks as |sectionLink|}}
        <SectionLink
          data-tag-name={{sectionLink.tagName}}
          @badgeText={{sectionLink.badgeText}}
          @content={{sectionLink.text}}
          @currentWhen={{sectionLink.currentWhen}}
          @models={{sectionLink.models}}
          @prefixColor={{sectionLink.prefixColor}}
          @prefixType={{sectionLink.prefixType}}
          @prefixValue={{sectionLink.prefixValue}}
          @route={{sectionLink.route}}
          @scrollIntoView={{and
            @scrollActiveLinkIntoView
            (eq sectionLink.name this.activeLink.name)
          }}
          @suffixCSSClass={{sectionLink.suffixCSSClass}}
          @suffixType={{sectionLink.suffixType}}
          @suffixValue={{sectionLink.suffixValue}}
          @title={{sectionLink.title}}
        />
      {{/each}}

      <AllTagsSectionLink
        @scrollActiveLinkIntoView={{@scrollActiveLinkIntoView}}
      />

      {{#if this.shouldDisplayDefaultConfig}}
        <SectionLink
          @content={{i18n "sidebar.sections.tags.configure_defaults"}}
          @linkName="configure-default-navigation-menu-tags"
          @model="sidebar"
          @prefixType="icon"
          @prefixValue="wrench"
          @query={{hash filter="default_navigation_menu_tags"}}
          @route="adminSiteSettingsCategory"
        />
      {{/if}}
    </Section>
  </template>
}
