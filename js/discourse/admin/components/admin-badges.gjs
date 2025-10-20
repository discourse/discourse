import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DBreadcrumbsItem from "discourse/components/d-breadcrumbs-item";
import DPageHeader from "discourse/components/d-page-header";
import NavItem from "discourse/components/nav-item";
import { i18n } from "discourse-i18n";
import EditBadgeGroupingsModal from "admin/components/modal/edit-badge-groupings";

export default class AdminBadges extends Component {
  @service adminBadges;
  @service modal;

  get badges() {
    return this.adminBadges.badges;
  }

  @action
  editGroupings() {
    this.modal.show(EditBadgeGroupingsModal, {
      model: {
        badgeGroupings: this.adminBadges.badgeGroupings,
        updateGroupings: (groupings) => {
          this.adminBadges.badgeGroupings = groupings;
        },
      },
    });
  }

  <template>
    <div class="badges">
      <DPageHeader
        @titleLabel={{i18n "admin.config.badges.title"}}
        @descriptionLabel={{i18n "admin.config.badges.header_description"}}
        @learnMoreUrl="https://meta.discourse.org/t/understanding-and-using-badges/32540"
      >
        <:breadcrumbs>
          <DBreadcrumbsItem @path="/admin" @label={{i18n "admin_title"}} />
          <DBreadcrumbsItem
            @path="/admin/badges"
            @label={{i18n "admin.config.badges.title"}}
          />
        </:breadcrumbs>
        <:actions as |actions|>
          <actions.Primary
            @route="adminBadges.show"
            @routeModels="new"
            @icon="plus"
            @label="admin.badges.new"
            class="new-badge"
          />

          <actions.Default
            @route="adminBadges.award"
            @routeModels="new"
            @icon="upload"
            @label="admin.badges.mass_award.title"
            class="award-badge"
          />

          <actions.Default
            @action={{this.editGroupings}}
            @title="admin.badges.group_settings"
            @label="admin.badges.group_settings"
            @icon="gear"
            class="edit-groupings-btn"
          />
        </:actions>
        <:tabs>
          <NavItem
            @route="adminBadges.settings"
            @label="settings"
            class="admin-badges-tabs__settings"
          />
          <NavItem
            @route="adminBadges.index"
            @label="admin.config.badges.title"
            @currentWhen="adminBadges.show adminBadges.index"
            class="admin-badges-tabs__index"
          />
        </:tabs>
      </DPageHeader>

      <div class="admin-container admin-config-page__main-area">
        {{outlet}}
      </div>
    </div>
  </template>
}
