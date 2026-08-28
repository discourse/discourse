import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { array, fn, hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import didUpdate from "@ember/render-modifiers/modifiers/did-update";
import AdminReport from "discourse/admin/components/admin-report";
import { eq } from "discourse/truth-helpers";
import DButton from "discourse/ui-kit/d-button";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import { i18n } from "discourse-i18n";

export default class PostersByMemberTypeReport extends Component {
  @tracked selectedGroupKey = this.args.model?.data?.[0]?.type ?? null;
  @tracked memberCount = null;

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

  get hasMemberCount() {
    return this.memberCount !== null;
  }

  get membersUsersLabel() {
    return i18n(
      "admin.dashboard.reports.posters_by_member_type_members.users_count",
      { count: this.memberCount }
    );
  }

  get membersPostsLabel() {
    return i18n(
      "admin.dashboard.reports.posters_by_member_type_members.posts_count",
      { count: this.selectedRow?.count ?? 0 }
    );
  }

  get membersAriaLabel() {
    return i18n(
      "admin.dashboard.reports.posters_by_member_type_members.title",
      {
        name: this.selectedRow?.name,
        users: this.membersUsersLabel,
        posts: this.membersPostsLabel,
      }
    );
  }

  get membersSubtitle() {
    return `${this.membersUsersLabel} · ${this.membersPostsLabel}`;
  }

  get deselectAriaLabel() {
    return i18n(
      "admin.dashboard.reports.posters_by_member_type_members.deselect",
      {
        name: this.selectedRow?.name,
      }
    );
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

  setSelectedGroupKey(key) {
    this.selectedGroupKey = key;
    this.memberCount = null;
  }

  @action
  resyncSelection() {
    if (!this.rows.some((row) => row.type === this.selectedGroupKey)) {
      this.setSelectedGroupKey(this.rows[0]?.type ?? null);
    }
  }

  @action
  selectRow(row) {
    this.setSelectedGroupKey(row.type);
  }

  @action
  selectRowOnKeydown(row, event) {
    if (event.key === "Enter" || event.key === " ") {
      event.preventDefault();
      this.selectRow(row);
    }
  }

  @action
  deselectGroup() {
    this.setSelectedGroupKey(null);
  }

  @action
  onMembersLoaded(report) {
    this.memberCount = report?.data?.length ?? 0;
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
            <td colspan="3">
              {{i18n "admin.dashboard.reports.totals_for_sample"}}
            </td>
          </tr>
          <tr>
            <td>—</td>
            <td class="posters-by-member-type-report__numeric">
              {{@model.total}}
            </td>
            <td class="posters-by-member-type-report__numeric">—</td>
          </tr>
        </tbody>
      </table>

      {{#if this.selectedRow}}
        <div class="posters-by-member-type-report__members">
          <div
            class="posters-by-member-type-report__members-header"
            aria-label={{this.membersAriaLabel}}
          >
            <div class="posters-by-member-type-report__members-heading">
              <h3 class="posters-by-member-type-report__members-name">
                {{this.selectedRow.name}}
              </h3>
              {{#if this.hasMemberCount}}
                <p class="posters-by-member-type-report__members-stats">
                  {{this.membersSubtitle}}
                </p>
              {{/if}}
            </div>
            <DButton
              class="btn-flat posters-by-member-type-report__members-close"
              @icon="xmark"
              @translatedAriaLabel={{this.deselectAriaLabel}}
              @action={{this.deselectGroup}}
            />
          </div>
          {{#each (array this.selectedGroupKey) key="@identity" as |groupKey|}}
            <AdminReport
              @dataSourceName="posters_by_member_type_members"
              @showHeader={{false}}
              @showFilteringUI={{false}}
              @onDataLoaded={{this.onMembersLoaded}}
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
