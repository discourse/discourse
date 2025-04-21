import Component from "@glimmer/component";
import { cached } from "@glimmer/tracking";
import { array, hash } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import SidebarEditNavigationMenuTagsModal from "discourse/components/sidebar/edit-navigation-menu/tags-modal";
import { hasDefaultSidebarTags } from "discourse/lib/sidebar/helpers";
import PMTagSectionLink from "discourse/lib/sidebar/user/tags-section/pm-tag-section-link";
import TagSectionLink from "discourse/lib/sidebar/user/tags-section/tag-section-link";
import { i18n } from "discourse-i18n";
import AllTagsSectionLink from "../common/all-tags-section-link";
import Section from "../section";
import SectionLink from "../section-link";

export default class SidebarUserTagsSection extends Component {
  @service currentUser;
  @service modal;
  @service pmTopicTrackingState;
  @service router;
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
      @sectionName="tags"
      @headerLinkText={{i18n "sidebar.sections.tags.header_link_text"}}
      @headerActions={{array
        (hash
          action=this.showModal
          title=(i18n "sidebar.sections.tags.header_action_title")
        )
      }}
      @headerActionsIcon="pencil"
      @collapsable={{@collapsable}}
    >
      {{#each this.sectionLinks as |sectionLink|}}
        <SectionLink
          @route={{sectionLink.route}}
          @title={{sectionLink.title}}
          @content={{sectionLink.text}}
          @currentWhen={{sectionLink.currentWhen}}
          @prefixType={{sectionLink.prefixType}}
          @prefixValue={{sectionLink.prefixValue}}
          @prefixColor={{sectionLink.prefixColor}}
          @badgeText={{sectionLink.badgeText}}
          @models={{sectionLink.models}}
          @suffixCSSClass={{sectionLink.suffixCSSClass}}
          @suffixValue={{sectionLink.suffixValue}}
          @suffixType={{sectionLink.suffixType}}
          data-tag-name={{sectionLink.tagName}}
        />
      {{/each}}

      <AllTagsSectionLink />

      {{#if this.shouldDisplayDefaultConfig}}
        <SectionLink
          @linkName="configure-default-navigation-menu-tags"
          @content={{i18n "sidebar.sections.tags.configure_defaults"}}
          @prefixType="icon"
          @prefixValue="wrench"
          @route="adminSiteSettingsCategory"
          @model="sidebar"
          @query={{hash filter="default_navigation_menu_tags"}}
        />
      {{/if}}
    </Section>
  </template>
}
