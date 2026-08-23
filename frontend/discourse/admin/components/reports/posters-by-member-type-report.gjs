import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { array, fn, hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import didUpdate from "@ember/render-modifiers/modifiers/did-update";
import AdminReport from "discourse/admin/components/admin-report";
import { eq } from "discourse/truth-helpers";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import { i18n } from "discourse-i18n";

export default class PostersByMemberTypeReport extends Component {
  @tracked selectedGroupKey = this.args.model?.data?.[0]?.type ?? null;

  get rows() {
    return this.args.model?.data ?? [];
  }

  get labels() {
    return this.args.model?.labels ?? [];
  }

  get nameLabel() {
    return this.labels[0]?.title;
  }

  get countLabel() {
    return this.labels[1]?.title;
  }

  get shareLabel() {
    return this.labels[2]?.title;
  }

  get selectedRow() {
    return this.rows.find((row) => row.type === this.selectedGroupKey);
  }

  get categoryIds() {
    const filter = this.args.model?.available_filters?.find(
      (f) => f.id === "category_ids"
    );
    return filter?.default ?? [];
  }

  get categoryIdsParam() {
    return this.categoryIds.join(",");
  }

  get startDate() {
    return moment(this.args.model?.start_date).format("YYYY-MM-DD");
  }

  get endDate() {
    return moment(this.args.model?.end_date).format("YYYY-MM-DD");
  }

  @action
  resyncSelection() {
    if (!this.rows.some((row) => row.type === this.selectedGroupKey)) {
      this.selectedGroupKey = this.rows[0]?.type ?? null;
    }
  }

  @action
  selectRow(row) {
    this.selectedGroupKey = row.type;
  }

  @action
  selectRowOnKeydown(row, event) {
    if (event.key === "Enter" || event.key === " ") {
      event.preventDefault();
      this.selectRow(row);
    }
  }

  <template>
    <div
      class="posters-by-member-type-report admin-report-table"
      {{didUpdate this.resyncSelection @model.data}}
    >
      <table class="posters-by-member-type-report__table table">
        <thead>
          <tr>
            <th>{{this.nameLabel}}</th>
            <th class="posters-by-member-type-report__numeric">
              {{this.countLabel}}
            </th>
            <th class="posters-by-member-type-report__numeric">
              {{this.shareLabel}}
            </th>
          </tr>
        </thead>
        <tbody>
          {{#each this.rows as |row|}}
            <tr
              class={{dConcatClass
                "posters-by-member-type-report__row"
                (if (eq row.type this.selectedGroupKey) "--selected")
              }}
              role="button"
              tabindex="0"
              {{on "click" (fn this.selectRow row)}}
              {{on "keydown" (fn this.selectRowOnKeydown row)}}
            >
              <td class="posters-by-member-type-report__name">{{row.name}}</td>
              <td
                class="posters-by-member-type-report__numeric"
              >{{row.count}}</td>
              <td
                class="posters-by-member-type-report__numeric"
              >{{row.share_formatted}}</td>
            </tr>
          {{/each}}
          <tr class="total-row">
            <td>{{i18n "admin.dashboard.reports.totals_for_sample"}}</td>
            <td class="posters-by-member-type-report__numeric">
              {{@model.total}}
            </td>
            <td class="posters-by-member-type-report__numeric">—</td>
          </tr>
        </tbody>
      </table>

      {{#if this.selectedRow}}
        <div class="posters-by-member-type-report__members">
          {{#each (array this.selectedGroupKey) key="@identity" as |groupKey|}}
            <AdminReport
              @dataSourceName="posters_by_member_type_members"
              @showHeader={{false}}
              @showFilteringUI={{false}}
              @filters={{hash
                startDate=this.startDate
                endDate=this.endDate
                customFilters=(hash
                  group=groupKey category_ids=this.categoryIdsParam
                )
              }}
            />
          {{/each}}
        </div>
      {{/if}}
    </div>
  </template>
}
