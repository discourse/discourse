import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import EditBadgeGroupingsModal from "discourse/admin/components/modal/edit-badge-groupings";
import DBreadcrumbsItem from "discourse/ui-kit/d-breadcrumbs-item";
import DNavItem from "discourse/ui-kit/d-nav-item";
import DPageHeader from "discourse/ui-kit/d-page-header";
import { i18n } from "discourse-i18n";

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
        @descriptionLabel={{i18n "admin.config.badges.header_description"}}
        @learnMoreUrl="https://meta.discourse.org/t/understanding-and-using-badges/32540"
        @titleLabel={{i18n "admin.config.badges.title"}}
      >
        <:breadcrumbs>
          <DBreadcrumbsItem @label={{i18n "admin_title"}} @path="/admin" />
          <DBreadcrumbsItem
            @label={{i18n "admin.config.badges.title"}}
            @path="/admin/badges"
          />
        </:breadcrumbs>
        <:actions as |actions|>
          <actions.Primary
            class="new-badge"
            @icon="plus"
            @label="admin.badges.new"
            @route="adminBadges.show"
            @routeModels="new"
          />

          <actions.Default
            class="award-badge"
            @icon="upload"
            @label="admin.badges.mass_award.title"
            @route="adminBadges.award"
            @routeModels="new"
          />

          <actions.Default
            class="edit-groupings-btn"
            @action={{this.editGroupings}}
            @icon="gear"
            @label="admin.badges.group_settings"
            @title="admin.badges.group_settings"
          />
        </:actions>
        <:tabs>
          <DNavItem
            class="admin-badges-tabs__settings"
            @label="settings"
            @route="adminBadges.settings"
          />
          <DNavItem
            class="admin-badges-tabs__index"
            @currentWhen="adminBadges.show adminBadges.index"
            @label="admin.config.badges.title"
            @route="adminBadges.index"
          />
        </:tabs>
      </DPageHeader>

      <div class="admin-container admin-config-page__main-area">
        {{outlet}}
      </div>
    </div>
  </template>
}
