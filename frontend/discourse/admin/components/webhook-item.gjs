import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import { LinkTo } from "@ember/routing";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import DropdownMenu from "discourse/components/dropdown-menu";
import { i18n } from "discourse-i18n";
import WebhookStatus from "admin/components/webhook-status";
import DMenu from "float-kit/components/d-menu";

export default class WebhookItem extends Component {
  @service router;

  @tracked webhook = this.args.webhook;
  deliveryStatuses = this.args.deliveryStatuses;

  @action
  onRegisterApi(api) {
    this.dMenu = api;
  }

  @action
  edit() {
    this.router.transitionTo("adminWebHooks.edit", this.webhook);
  }

  @action
  events() {
    this.router.transitionTo("adminWebHooks.show", this.webhook);
  }

  <template>
    <tr class="d-table__row">
      <td class="d-table__cell --overview key">
        <LinkTo @route="adminWebHooks.show" @model={{this.webhook}}>
          <WebhookStatus
            @deliveryStatuses={{this.deliveryStatuses}}
            @webhook={{this.webhook}}
          />
        </LinkTo>
      </td>
      <td class="d-table__cell --detail key-url">
        <LinkTo @route="adminWebHooks.edit" @model={{this.webhook}}>
          {{this.webhook.payload_url}}
        </LinkTo>
      </td>
      <td class="d-table__cell --detail key-description">
        {{this.webhook.description}}
      </td>
      <td class="d-table__cell --controls key-controls">
        <div class="d-table__cell-actions">
          <DButton
            @action={{this.edit}}
            @label="admin.web_hooks.edit"
            @title="admin.web_hooks.edit"
            class="btn-default btn-small"
          />
          <DMenu
            @identifier="webhook-menu"
            @title={{i18n "admin.config_areas.user_fields.more_options.title"}}
            @icon="ellipsis-vertical"
            @onRegisterApi={{this.onRegisterApi}}
          >
            <:content>
              <DropdownMenu as |dropdown|>
                <dropdown.item>
                  <DButton
                    @action={{this.events}}
                    @icon="list"
                    @label="admin.web_hooks.show"
                    @title="admin.web_hooks.show"
                    class="admin-web-hook__show"
                  />
                </dropdown.item>
                <dropdown.item>
                  <DButton
                    @action={{fn @destroy this.webhook}}
                    @icon="trash-can"
                    @label="admin.web_hooks.delete"
                    @title="admin.web_hooks.delete"
                    class="btn-danger admin-web-hook__delete"
                  />
                </dropdown.item>
              </DropdownMenu>
            </:content>
          </DMenu>
        </div>
      </td>
    </tr>
  </template>
}
