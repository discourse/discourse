import { cached } from "@glimmer/tracking";
import { array, hash } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { hasDefaultSidebarCategories } from "discourse/lib/sidebar/helpers";
import Category from "discourse/models/category";
import { debounce } from "discourse-common/utils/decorators";
import { i18n } from "discourse-i18n";
import AllCategoriesSectionLink from "../common/all-categories-section-link";
import CommonCategoriesSection from "../common/categories-section";
import EditNavigationMenuCategoriesModal from "../edit-navigation-menu/categories-modal";
import Section from "../section";
import SectionLink from "../section-link";

export const REFRESH_COUNTS_APP_EVENT_NAME =
  "sidebar:refresh-categories-section-counts";

export default class SidebarUserCategoriesSection extends CommonCategoriesSection {
  @service appEvents;
  @service currentUser;
  @service modal;
  @service router;

  constructor() {
    super(...arguments);

    this.callbackId = this.topicTrackingState.onStateChange(() => {
      this._refreshCounts();
    });

    this.appEvents.on(REFRESH_COUNTS_APP_EVENT_NAME, this, this._refreshCounts);
  }

  willDestroy() {
    super.willDestroy(...arguments);

    this.topicTrackingState.offStateChange(this.callbackId);

    this.appEvents.off(
      REFRESH_COUNTS_APP_EVENT_NAME,
      this,
      this._refreshCounts
    );
  }

  // TopicTrackingState changes or plugins can trigger this function so we debounce to ensure we're not refreshing
  // unnecessarily.
  @debounce(300)
  _refreshCounts() {
    this.sectionLinks.forEach((sectionLink) => sectionLink.refreshCounts());
  }

  @cached
  get categories() {
    if (this.currentUser.sidebarCategoryIds?.length > 0) {
      return Category.findByIds(this.currentUser.sidebarCategoryIds);
    } else {
      return this.topSiteCategories;
    }
  }

  get shouldDisplayDefaultConfig() {
    return this.currentUser.admin && !this.hasDefaultSidebarCategories;
  }

  get hasDefaultSidebarCategories() {
    return hasDefaultSidebarCategories(this.siteSettings);
  }

  @action
  showModal() {
    this.modal.show(EditNavigationMenuCategoriesModal);
  }

  <template>
    <Section
      @sectionName="categories"
      @headerLinkText={{i18n "sidebar.sections.categories.header_link_text"}}
      @headerActions={{array
        (hash
          action=this.showModal
          title=(i18n "sidebar.sections.categories.header_action_title")
        )
      }}
      @headerActionsIcon="pencil"
      @collapsable={{@collapsable}}
    >

      {{#each this.sectionLinks as |sectionLink|}}
        <SectionLink
          @route={{sectionLink.route}}
          @query={{sectionLink.query}}
          @title={{sectionLink.title}}
          @content={{sectionLink.text}}
          @currentWhen={{sectionLink.currentWhen}}
          @model={{sectionLink.model}}
          @badgeText={{sectionLink.badgeText}}
          @prefixBadge={{sectionLink.prefixBadge}}
          @prefixType={{sectionLink.prefixType}}
          @prefixValue={{sectionLink.prefixValue}}
          @prefixColor={{sectionLink.prefixColor}}
          @suffixCSSClass={{sectionLink.suffixCSSClass}}
          @suffixValue={{sectionLink.suffixValue}}
          @suffixType={{sectionLink.suffixType}}
          data-category-id={{sectionLink.category.id}}
        />
      {{/each}}

      <AllCategoriesSectionLink />

      {{#if this.shouldDisplayDefaultConfig}}
        <SectionLink
          @linkName="configure-default-navigation-menu-categories"
          @content={{i18n "sidebar.sections.categories.configure_defaults"}}
          @prefixType="icon"
          @prefixValue="wrench"
          @route="adminSiteSettingsCategory"
          @model="sidebar"
          @query={{hash filter="default_navigation_menu_categories"}}
        />
      {{/if}}
    </Section>
  </template>
}
