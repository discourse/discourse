import Component from "@glimmer/component";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import { LinkTo } from "@ember/routing";
import { service } from "@ember/service";
import WebhookStatus from "discourse/admin/components/webhook-status";
import DMenu from "discourse/float-kit/components/d-menu";
import DButton from "discourse/ui-kit/d-button";
import DDropdownMenu from "discourse/ui-kit/d-dropdown-menu";
import { i18n } from "discourse-i18n";

export default class WebhookItem extends Component {
  @service router;

  @action
  onRegisterApi(api) {
    this.dMenu = api;
  }

  @action
  edit() {
    this.router.transitionTo("adminWebHooks.edit", this.args.webhook);
  }

  @action
  events() {
    this.router.transitionTo("adminWebHooks.show", this.args.webhook);
  }

  <template>
    <tr class="d-table__row">
      <td class="d-table__cell --overview key">
        <LinkTo @model={{@webhook}} @route="adminWebHooks.show">
          <WebhookStatus
            @deliveryStatuses={{@deliveryStatuses}}
            @webhook={{@webhook}}
          />
        </LinkTo>
      </td>
      <td class="d-table__cell --detail key-url">
        <LinkTo @model={{@webhook}} @route="adminWebHooks.edit">
          {{@webhook.payload_url}}
        </LinkTo>
      </td>
      <td class="d-table__cell --detail key-description">
        {{@webhook.description}}
      </td>
      <td class="d-table__cell --controls key-controls">
        <div class="d-table__cell-actions">
          <DButton
            class="btn-default btn-small"
            @action={{this.edit}}
            @label="admin.web_hooks.edit"
            @title="admin.web_hooks.edit"
          />
          <DMenu
            @icon="ellipsis-vertical"
            @identifier="webhook-menu"
            @onRegisterApi={{this.onRegisterApi}}
            @title={{i18n "admin.config_areas.user_fields.more_options.title"}}
          >
            <:content>
              <DDropdownMenu as |dropdown|>
                <dropdown.item>
                  <DButton
                    class="admin-web-hook__show"
                    @action={{this.events}}
                    @icon="list"
                    @label="admin.web_hooks.show"
                    @title="admin.web_hooks.show"
                  />
                </dropdown.item>
                <dropdown.item>
                  <DButton
                    class="btn-danger admin-web-hook__delete"
                    @action={{fn @destroy @webhook}}
                    @icon="trash-can"
                    @label="admin.web_hooks.delete"
                    @title="admin.web_hooks.delete"
                  />
                </dropdown.item>
              </DDropdownMenu>
            </:content>
          </DMenu>
        </div>
      </td>
    </tr>
  </template>
}
