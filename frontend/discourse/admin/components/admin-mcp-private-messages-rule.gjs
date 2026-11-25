import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import AdminConfigAreaCard from "discourse/admin/components/admin-config-area-card";
import DToggleSwitch from "discourse/ui-kit/d-toggle-switch";

/**
 * Turns agent access to personal messages on or off. The rule is stored while
 * access is off, so switching access off saves the rule and switching it back
 * on deletes it. Each change saves immediately.
 */
export default class AdminMcpPrivateMessagesRule extends Component {
  /**
   * @returns {boolean} Whether agents can reach personal messages.
   */
  get accessible() {
    return !this.args.ruleKind.active;
  }

  @action
  toggle() {
    return this.accessible ? this.args.onSave({}) : this.args.onDelete();
  }

  <template>
    <AdminConfigAreaCard
      class="admin-mcp-content-restrictions__rule --private-messages"
      @description="admin.config.mcp.content_restrictions.private_messages.description"
      @heading="admin.config.mcp.content_restrictions.private_messages.title"
    >
      <:content>
        <DToggleSwitch
          class="admin-mcp-content-restrictions__private-messages-toggle"
          @label="admin.config.mcp.content_restrictions.private_messages.toggle"
          @state={{this.accessible}}
          {{on "click" this.toggle}}
        />
      </:content>
    </AdminConfigAreaCard>
  </template>
}
