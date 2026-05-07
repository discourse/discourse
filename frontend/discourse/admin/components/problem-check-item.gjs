import Component from "@glimmer/component";
import { fn, get } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import formatDate from "discourse/helpers/format-date";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { notEq } from "discourse/truth-helpers";
import { i18n } from "discourse-i18n";

const STATUS_CLASSES = {
  passing: "--success",
  failing: "--critical",
};

const STATUS_LABELS = {
  passing: i18n("admin.config.problem_checks.passing"),
  failing: i18n("admin.config.problem_checks.failing"),
};

export default class ProblemCheckItem extends Component {
  @service router;

  @action
  async ignore(tracker) {
    try {
      await ajax(`/admin/problem_checks/${tracker.id}/ignore.json`, {
        type: "PUT",
      });
      this.router.refresh();
    } catch (error) {
      popupAjaxError(error);
    }
  }

  @action
  async watch(tracker) {
    try {
      await ajax(`/admin/problem_checks/${tracker.id}/watch.json`, {
        type: "PUT",
      });
      this.router.refresh();
    } catch (error) {
      popupAjaxError(error);
    }
  }

  <template>
    <tr class="d-table__row --{{@tracker.status}}">
      <td class="d-table__cell --overview">
        <div class="status-label {{get STATUS_CLASSES @tracker.status}}">
          <div class="status-label-indicator"></div>
          <div class="status-label-text">
            {{get STATUS_LABELS @tracker.status}}
          </div>
        </div>
      </td>
      <td class="d-table__cell --detail">
        <div class="d-table__mobile-label">{{i18n
            "admin.config.problem_checks.identifier"
          }}</div>
        {{@tracker.identifier}}
      </td>
      <td class="d-table__cell --detail">
        <div class="d-table__mobile-label">{{i18n
            "admin.config.problem_checks.target"
          }}</div>
        {{#if (notEq @tracker.target "__NULL__")}}
          {{@tracker.target}}
        {{/if}}
      </td>
      <td class="d-table__cell --detail">
        <div class="d-table__mobile-label">{{i18n
            "admin.config.problem_checks.last_run_at"
          }}</div>
        {{#if @tracker.last_run_at}}
          {{formatDate @tracker.last_run_at leaveAgo="true"}}
        {{/if}}
      </td>
      <td class="d-table__cell --controls">
        <div class="d-table__cell-actions">
          {{#if @tracker.ignored}}
            <DButton
              @action={{fn this.watch @tracker}}
              @label="admin.config.problem_checks.watch"
              @icon="eye"
              class="btn-default btn-small"
            />
          {{else}}
            <DButton
              @action={{fn this.ignore @tracker}}
              @label="admin.config.problem_checks.ignore"
              @icon="eye-slash"
              class="btn-default btn-small"
            />
          {{/if}}
        </div>
      </td>
    </tr>
  </template>
}
