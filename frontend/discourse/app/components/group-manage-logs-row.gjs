import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn, hash } from "@ember/helper";
import { action, set } from "@ember/object";
import DButton from "discourse/ui-kit/d-button";
import dAgeWithTooltip from "discourse/ui-kit/helpers/d-age-with-tooltip";
import dAvatar from "discourse/ui-kit/helpers/d-avatar";
import { i18n } from "discourse-i18n";

export default class GroupManageLogsRow extends Component {
  @tracked expandDetails = false;

  @action
  toggleDetails() {
    this.expandDetails = !this.expandDetails;
  }

  @action
  filter(params) {
    set(this.args.filters, params.key, params.value);
  }

  <template>
    <tr class="group-manage-logs-row">
      <td>
        <DButton
          class="btn-default"
          @action={{fn this.filter (hash value=@log.action key="action")}}
          @translatedLabel={{@log.actionTitle}}
        />
      </td>

      <td>
        <span>{{dAvatar @log.acting_user imageSize="tiny"}}</span>
        <DButton
          class="btn-default"
          @action={{fn
            this.filter
            (hash value=@log.acting_user.username key="acting_user")
          }}
          @translatedLabel={{@log.acting_user.username}}
        />
      </td>

      <td>
        {{#if @log.target_user}}
          <span>{{dAvatar @log.target_user imageSize="tiny"}}</span>
          <DButton
            class="btn-default"
            @action={{fn
              this.filter
              (hash value=@log.target_user.username key="target_user")
            }}
            @translatedLabel={{@log.target_user.username}}
          />
        {{/if}}
      </td>

      <td>
        {{#if @log.subject}}
          <DButton
            class="btn-default"
            @action={{fn this.filter (hash value=@log.subject key="subject")}}
            @translatedLabel={{@log.subject}}
          />
        {{/if}}
      </td>

      <td>{{dAgeWithTooltip @log.created_at format="medium"}}</td>

      <td class="group-manage-logs-expand-details">
        {{#if @log.prev_value}}
          <DButton
            class="btn-default"
            @action={{this.toggleDetails}}
            @icon={{if this.expandDetails "angle-up" "angle-down"}}
          />
        {{/if}}
      </td>
    </tr>

    {{#if this.expandDetails}}
      <tr>
        <td colspan="6">
          <p>
            <strong>{{i18n "groups.manage.logs.from"}}</strong>:
            <code>{{@log.prev_value}}</code>
          </p>

          <p>
            <strong>{{i18n "groups.manage.logs.to"}}</strong>:
            <code>{{@log.new_value}}</code>
          </p>
        </td>
      </tr>
    {{/if}}
  </template>
}
