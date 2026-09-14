import { cached } from "@glimmer/tracking";
import { hash } from "@ember/helper";
import { service } from "@ember/service";
import { debounce } from "discourse/lib/decorators";
import { findActiveLink } from "discourse/lib/sidebar/active-link";
import { hasDefaultSidebarCategories } from "discourse/lib/sidebar/helpers";
import Category from "discourse/models/category";
import { and, eq } from "discourse/truth-helpers";
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
  @service categoryTypeChooser;
  @service currentUser;
  @service modal;
  @service navigationMenu;
  @service router;
  @service siteSettings;

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

  @cached
  get activeLink() {
    return findActiveLink(this.sectionLinks, this.router);
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

  @cached
  get headerActions() {
    const actions = [];

    if (this.currentUser.can_create_category) {
      actions.push({
        id: "new-category",
        action: () => this.createCategory(),
        title: i18n("sidebar.sections.categories.header_action_new"),
      });
    }

    actions.push({
      id: "edit-categories",
      action: () => this.modal.show(EditNavigationMenuCategoriesModal),
      title: i18n(
        `sidebar.sections.categories.header_action_edit_${this.navigationMenu.displayMode}`
      ),
    });

    return actions;
  }

  get headerActionsIcon() {
    return this.headerActions.length > 1 ? "ellipsis-vertical" : "pencil";
  }

  createCategory() {
    this.categoryTypeChooser.createCategory();
  }

  // TopicTrackingState changes or plugins can trigger this function so we debounce to ensure we're not refreshing
  // unnecessarily.
  @debounce(300)
  _refreshCounts() {
    this.sectionLinks.forEach((sectionLink) => sectionLink.refreshCounts());
  }

  <template>
    <Section
      @activeLink={{this.activeLink}}
      @collapsable={{@collapsable}}
      @expandWhenActive={{@expandActiveSection}}
      @headerActions={{this.headerActions}}
      @headerActionsIcon={{this.headerActionsIcon}}
      @headerLinkText={{i18n "sidebar.sections.categories.header_link_text"}}
      @sectionName="categories"
      @toggleNavigationMenu={{@toggleNavigationMenu}}
    >

      {{#each this.sectionLinks as |sectionLink|}}
        <SectionLink
          data-category-id={{sectionLink.category.id}}
          @badgeText={{sectionLink.badgeText}}
          @content={{sectionLink.text}}
          @currentWhen={{sectionLink.currentWhen}}
          @model={{sectionLink.model}}
          @prefixBadge={{sectionLink.prefixBadge}}
          @prefixColor={{sectionLink.prefixColor}}
          @prefixType={{sectionLink.prefixType}}
          @prefixValue={{sectionLink.prefixValue}}
          @query={{sectionLink.query}}
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

      <AllCategoriesSectionLink
        @scrollActiveLinkIntoView={{@scrollActiveLinkIntoView}}
      />

      {{#if this.shouldDisplayDefaultConfig}}
        <SectionLink
          @content={{i18n "sidebar.sections.categories.configure_defaults"}}
          @linkName="configure-default-navigation-menu-categories"
          @model="sidebar"
          @prefixType="icon"
          @prefixValue="wrench"
          @query={{hash filter="default_navigation_menu_categories"}}
          @route="adminSiteSettingsCategory"
        />
      {{/if}}
    </Section>
  </template>
}
