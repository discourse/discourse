import Component from "@glimmer/component";
import { array, concat, fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { service } from "@ember/service";
import { TrackedObject } from "@ember-compat/tracked-built-ins";
import { eq } from "truth-helpers";
import DToggleSwitch from "discourse/components/d-toggle-switch";
import icon from "discourse/helpers/d-icon";
import { i18n } from "discourse-i18n";
import AdminConfigAreaCard from "admin/components/admin-config-area-card";
import AdminFilterControls from "admin/components/admin-filter-controls";

export default class AdminConfigAreasUpcomingChanges extends Component {
  @service site;

  get upcomingChanges() {
    return this.args.upcomingChanges.map((change) => {
      return new TrackedObject(change);
    });
  }

  get dropdownOptions() {
    return [
      {
        label: i18n("admin.upcoming_changes.filter.all"),
        value: "all",
        filterFn: () => true,
      },
      {
        label: i18n("admin.upcoming_changes.filter.enabled"),
        value: "enabled",
        filterFn: (change) => change.value,
      },
      {
        label: i18n("admin.upcoming_changes.filter.disabled"),
        value: "disabled",
        filterFn: (change) => !change.value,
      },
      {
        label: i18n("admin.upcoming_changes.filter.low_risk"),
        value: "low_risk",
        filterFn: (change) => change.upcoming_change.risk === "low",
      },
      {
        label: i18n("admin.upcoming_changes.filter.medium_risk"),
        value: "medium_risk",
        filterFn: (change) => change.upcoming_change.risk === "medium",
      },
      {
        label: i18n("admin.upcoming_changes.filter.high_risk"),
        value: "high_risk",
        filterFn: (change) => change.upcoming_change.risk === "high",
      },
      {
        label: i18n("admin.upcoming_changes.filter.type_feature"),
        value: "feature",
        filterFn: (change) => change.upcoming_change.type === "feature",
      },
      {
        label: i18n("admin.upcoming_changes.filter.type_misc"),
        value: "misc",
        filterFn: (change) => change.upcoming_change.type === "misc",
      },
    ];
  }

  get initialDropdownValue() {
    return "all";
  }

  get riskFilterOptions() {
    return [
      {
        name: i18n("admin.upcoming_changes.filter.all"),
        value: "all",
      },
      {
        name: i18n("admin.upcoming_changes.filter.medium_risk"),
        value: "medium_risk",
      },
      {
        name: i18n("admin.upcoming_changes.filter.high_risk"),
        value: "high_risk",
      },
    ];
  }

  riskIcon(risk) {
    switch (risk) {
      case "low":
        return "circle-check";
      case "medium":
        return "circle-half-stroke";
      case "high":
        return "triangle-exclamation";
      default:
        return "question";
    }
  }

  typeIcon(type) {
    switch (type) {
      case "feature":
        return "flask";
      default:
        return;
    }
  }

  toggleChange(change) {
    change.value = !change.value;
  }

  <template>
    <AdminFilterControls
      @array={{this.upcomingChanges}}
      @searchableProps={{array
        "humanized_name"
        "description"
        "plugin_identifier"
      }}
      @dropdownOptions={{this.dropdownOptions}}
      @inputPlaceholder={{i18n
        "admin.upcoming_changes.filter.search_placeholder"
      }}
      @noResultsMessage={{i18n
        "admin.upcoming_changes.filter.search_placeholder"
      }}
    >
      <:content as |upcomingChanges|>
        <ul class="color-palette__list">
          {{#each upcomingChanges as |change|}}
            <AdminConfigAreaCard
              class="upcoming-change-card"
              @translatedHeading={{change.humanized_name}}
              @translatedDescription={{change.description}}
            >
              <:footer>
                {{#if change.upcoming_change.plugin_identifier}}
                  <img
                    src={{concat
                      "/images/upcoming_change_"
                      change.setting
                      ".png"
                    }}
                    class="upcoming-change-card__image"
                  />
                {{/if}}
              </:footer>

              <:headerAction>
                <DToggleSwitch
                  @state={{change.value}}
                  {{on "click" (fn this.toggleChange change)}}
                />
              </:headerAction>
              <:content>
                {{#if change.upcoming_change.plugin_identifier}}
                  For plugin
                  <a
                    href="/admin/plugins/calendar"
                  >{{change.upcoming_change.plugin_identifier}}<p></p></a>
                {{/if}}
                <div class="theme-card__badges">
                  <span
                    title={{i18n
                      (concat
                        "admin.upcoming_changes.statuses."
                        change.upcoming_change.status
                      )
                    }}
                    class="theme-card__badge"
                  >
                    {{icon "far-circle-dot"}}
                    {{i18n
                      (concat
                        "admin.upcoming_changes.statuses."
                        change.upcoming_change.status
                      )
                    }}
                  </span>

                  <span
                    title={{i18n
                      (concat
                        "admin.upcoming_changes.risks."
                        change.upcoming_change.risk
                      )
                    }}
                    class="theme-card__badge"
                  >
                    {{icon (this.riskIcon change.upcoming_change.risk)}}
                    {{i18n
                      (concat
                        "admin.upcoming_changes.risks."
                        change.upcoming_change.risk
                      )
                    }}
                  </span>

                  {{#unless (eq change.upcoming_change.type "misc")}}
                    <span
                      title={{i18n
                        (concat
                          "admin.upcoming_changes.types."
                          change.upcoming_change.type
                        )
                      }}
                      class="theme-card__badge"
                    >
                      {{icon (this.typeIcon change.upcoming_change.type)}}
                      {{i18n
                        (concat
                          "admin.upcoming_changes.types."
                          change.upcoming_change.type
                        )
                      }}
                    </span>
                  {{/unless}}
                </div>
              </:content>
            </AdminConfigAreaCard>
          {{/each}}
        </ul>
      </:content>
    </AdminFilterControls>
  </template>
}
