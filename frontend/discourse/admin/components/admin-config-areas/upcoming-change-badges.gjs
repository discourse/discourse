import Component from "@glimmer/component";
import { concat } from "@ember/helper";
import DTooltip from "discourse/float-kit/components/d-tooltip";
import concatClass from "discourse/helpers/concat-class";
import icon from "discourse/helpers/d-icon";
import { i18n } from "discourse-i18n";

const UpcomingChangeBadge = <template>
  <span
    class={{concatClass "upcoming-change__badge" "--has-tooltip" @badgeClass}}
  >
    <span class="upcoming-change__badge-content">
      {{icon @icon}}
      {{i18n @badgeLabelKey}}
    </span>
    {{yield}}
  </span>
</template>;

export default class UpcomingChangeBadges extends Component {
  impactRoleIcon(impactRole) {
    switch (impactRole) {
      case "admins":
      case "moderators":
      case "staff":
        return "shield-halved";
      case "all_members":
        return "users";
      case "developers":
        return "code";
    }
  }

  impactTypeIcon(impactType) {
    switch (impactType) {
      case "feature":
        return "wand-magic-sparkles";
      case "other":
        return "discourse-other-tab";
      case "site_setting_default":
        return "gear";
    }
  }

  <template>
    <div class="upcoming-change__badges">
      <DTooltip
        @content={{i18n
          (concat
            "admin.upcoming_changes.status_descriptions." @upcomingChange.status
          )
        }}
      >
        <:trigger>
          <UpcomingChangeBadge
            @icon="flask"
            @badgeClass={{concat "--status-" @upcomingChange.status}}
            @badgeLabelKey={{concat
              "admin.upcoming_changes.statuses."
              @upcomingChange.status
            }}
          >

            <span class="upcoming-change__badge-info">
              {{icon "info"}}
            </span>
          </UpcomingChangeBadge>
        </:trigger>
      </DTooltip>

      <UpcomingChangeBadge
        @icon={{this.impactRoleIcon @upcomingChange.impact_role}}
        @badgeClass={{concat "--impact-role-" @upcomingChange.impact_role}}
        @badgeLabelKey={{concat
          "admin.upcoming_changes.impact_roles."
          @upcomingChange.impact_role
        }}
      />

      <UpcomingChangeBadge
        @icon={{this.impactTypeIcon @upcomingChange.impact_type}}
        @badgeClass={{concat "--impact-type-" @upcomingChange.impact_type}}
        @badgeLabelKey={{concat
          "admin.upcoming_changes.impact_types."
          @upcomingChange.impact_type
          "_type"
        }}
      />
    </div>
  </template>
}
