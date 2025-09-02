import Component from "@glimmer/component";
import { array, concat, fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { TrackedObject } from "@ember-compat/tracked-built-ins";
import { eq } from "truth-helpers";
import DButton from "discourse/components/d-button";
import DToggleSwitch from "discourse/components/d-toggle-switch";
import DropdownMenu from "discourse/components/dropdown-menu";
import icon from "discourse/helpers/d-icon";
import { bind } from "discourse/lib/decorators";
import { i18n } from "discourse-i18n";
import AdminFilterControls from "admin/components/admin-filter-controls";
import DMenu from "float-kit/components/d-menu";

export default class AdminConfigAreasUpcomingChanges extends Component {
  @service site;

  registeredMenus = {};

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
      {
        label: i18n("admin.upcoming_changes.filter.status_pre_alpha"),
        value: "pre_alpha",
        filterFn: (change) => change.upcoming_change.status === "pre_alpha",
      },
      {
        label: i18n("admin.upcoming_changes.filter.status_alpha"),
        value: "alpha",
        filterFn: (change) => change.upcoming_change.status === "alpha",
      },
      {
        label: i18n("admin.upcoming_changes.filter.status_beta"),
        value: "beta",
        filterFn: (change) => change.upcoming_change.status === "beta",
      },
      {
        label: i18n("admin.upcoming_changes.filter.status_stable"),
        value: "stable",
        filterFn: (change) => change.upcoming_change.status === "stable",
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

  @action
  showImage(change) {
    if (change.upcoming_change.image_url) {
      window.open(change.upcoming_change.image_url, "_blank");
      this.registeredMenus[change.setting]?.close();
    }
  }

  @bind
  onRegisterMenuForRow(setting, menuApi) {
    this.registeredMenus[setting] = menuApi;
  }

  // TODO (martin) We probably will have more actions here in future,
  // all we have now is to show the image. Even that, we probably need
  // to show the image in a lightbox instead.
  hasChangeActions(change) {
    return !!change.upcoming_change.image_url;
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
        <table class="d-table upcoming-changes-table">
          <thead class="d-table__header">
            <tr class="d-table__row">
              <th
                class="d-table__header-cell upcoming-change__name-header"
              >{{i18n "admin.upcoming_changes.name"}}</th>
              <th
                class="d-table__header-cell upcoming-change__labels-header"
              >{{i18n "admin.upcoming_changes.labels"}}</th>
              <th
                class="d-table__header-cell upcoming-change__enabled-header"
              >{{i18n "admin.upcoming_changes.enabled"}}</th>
              <th
                class="d-table__header-cell upcoming-change__actions-header"
              ></th>
            </tr>
          </thead>
          <tbody class="d-table__body">
            {{#each upcomingChanges as |change|}}
              <tr class="d-table__row upcoming-change-row">
                <td class="d-table__cell --overview">
                  <div class="d-table__overview-name">
                    {{change.humanized_name}}
                  </div>
                  {{#if change.description}}
                    <div
                      class="d-table__overview-about upcoming-change__description"
                    >
                      {{change.description}}
                    </div>
                  {{/if}}

                  {{#if change.plugin}}
                    <span
                      class="upcoming-change__plugin upcoming-change__badge"
                    >
                      {{icon "plug"}}
                      {{change.plugin}}
                    </span>
                  {{/if}}
                </td>
                <td class="d-table__cell --detail upcoming-change__labels">
                  <div class="d-table__mobile-label">
                    {{i18n "admin.upcoming_changes.labels"}}
                  </div>
                  <div class="upcoming-change__badges">
                    <span
                      title={{i18n
                        (concat
                          "admin.upcoming_changes.statuses."
                          change.upcoming_change.status
                        )
                      }}
                      class="upcoming-change__badge"
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
                      class="upcoming-change__badge"
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
                        class="upcoming-change__badge"
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
                </td>
                <td class="d-table__cell --detail">
                  <div class="d-table__mobile-label">
                    {{i18n "admin.upcoming_changes.enabled"}}
                  </div>
                  <DToggleSwitch
                    @state={{change.value}}
                    class="upcoming-change__toggle"
                    {{on "click" (fn this.toggleChange change)}}
                  />
                </td>
                <td class="d-table__cell --controls">
                  {{#if (this.hasChangeActions change)}}
                    <div class="d-table__cell-actions">
                      <DMenu
                        @identifier="upcoming-change-menu"
                        @title={{i18n
                          "admin.config_areas.flags.more_options.title"
                        }}
                        @icon="ellipsis"
                        @class="btn-default upcoming-change__more-actions"
                        @onRegisterApi={{fn
                          this.onRegisterMenuForRow
                          change.setting
                        }}
                      >
                        <:content>
                          <DropdownMenu as |dropdown|>
                            <dropdown.item>
                              <DButton
                                class="btn-transparent upcoming-change__show-image"
                                @label="admin.upcoming_changes.show_image"
                                @icon="image"
                                @action={{this.showImage change}}
                              />
                            </dropdown.item>
                          </DropdownMenu>
                        </:content>
                      </DMenu>
                    </div>
                  {{/if}}
                </td>
              </tr>
            {{/each}}
          </tbody>
        </table>
      </:content>
    </AdminFilterControls>
  </template>
}
