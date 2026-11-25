import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import AdminConfigAreaCard from "discourse/admin/components/admin-config-area-card";
import { lookupMcpContentRuleComponent } from "discourse/admin/lib/mcp-content-rule-components";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import DButton from "discourse/ui-kit/d-button";
import { i18n } from "discourse-i18n";

const UnknownRuleCard = <template>
  <AdminConfigAreaCard
    class="admin-mcp-content-restrictions__rule --unknown"
    @translatedHeading={{@title}}
  >
    <:content>
      <p class="admin-mcp-content-restrictions__warning">
        {{i18n "admin.config.mcp.content_restrictions.unknown_rule"}}
      </p>
      <DButton
        class="btn-danger admin-mcp-content-restrictions__delete"
        @action={{@onDelete}}
        @label="admin.config.mcp.content_restrictions.delete_rule"
      />
    </:content>
  </AdminConfigAreaCard>
</template>;

/**
 * The MCP content restrictions page. It shows one card per content rule kind,
 * using the component registered for the kind, and a card for every stored
 * rule whose kind is no longer known so it can be deleted.
 */
export default class AdminMcpContentRestrictions extends Component {
  @service dialog;
  @service toasts;

  /** The payload after a save or delete, which replaces the route model. */
  @tracked _payload = null;

  /**
   * @returns {Object} The content restrictions payload.
   */
  get payload() {
    return this._payload ?? this.args.model;
  }

  /**
   * @returns {Array<{ruleKind: Object, component: Component|undefined}>}
   */
  get ruleKinds() {
    return this.payload.rule_kinds.map((ruleKind) => ({
      ruleKind,
      component: lookupMcpContentRuleComponent(ruleKind.admin_component_id),
    }));
  }

  /**
   * Saves a rule kind's config. Turning a rule on can switch tools off, so
   * that asks for confirmation first, naming the tools.
   *
   * @param {Object} ruleKind - The rule kind's entry from the payload.
   * @param {Object} config - The config to store.
   * @returns {Promise<boolean>} Whether the rule was saved.
   */
  @action
  async save(ruleKind, config) {
    const disabled = ruleKind.newly_disables ?? [];
    if (disabled.length > 0 && !(await this.#confirmDisabling(disabled))) {
      return false;
    }

    try {
      this._payload = await ajax(
        `/admin/mcp/content-restrictions/${ruleKind.name}.json`,
        {
          type: "PUT",
          contentType: "application/json",
          data: JSON.stringify({ config }),
        }
      );
      this.toasts.success({
        data: { message: i18n("admin.config.mcp.content_restrictions.saved") },
      });
      return true;
    } catch (error) {
      popupAjaxError(error);
      return false;
    }
  }

  /**
   * Deletes a stored rule, which turns its restriction off.
   *
   * @param {string} name - The rule kind's name.
   * @returns {Promise<void>}
   */
  @action
  async delete(name) {
    try {
      await ajax(`/admin/mcp/content-restrictions/${name}.json`, {
        type: "DELETE",
      });
      this._payload = await ajax("/admin/mcp/content-restrictions.json");
      this.toasts.success({
        data: {
          message: i18n("admin.config.mcp.content_restrictions.removed"),
        },
      });
    } catch (error) {
      popupAjaxError(error);
    }
  }

  #confirmDisabling(ids) {
    const titles = this.payload.primitive_titles ?? {};

    return new Promise((resolve) => {
      this.dialog.confirm({
        message: i18n(
          "admin.config.mcp.content_restrictions.confirm_disabling",
          {
            count: ids.length,
            tools: ids.map((id) => titles[id] ?? id).join(", "),
          }
        ),
        confirmButtonLabel:
          "admin.config.mcp.content_restrictions.confirm_disabling_button",
        didConfirm: () => resolve(true),
        didCancel: () => resolve(false),
      });
    });
  }

  <template>
    <div class="admin-mcp-content-restrictions">
      <div class="admin-mcp-content-restrictions__rules">
        {{#each this.ruleKinds as |entry|}}
          {{#if entry.component}}
            <entry.component
              @onDelete={{fn this.delete entry.ruleKind.name}}
              @onSave={{fn this.save entry.ruleKind}}
              @ruleKind={{entry.ruleKind}}
            />
          {{else if entry.ruleKind.active}}
            <UnknownRuleCard
              @onDelete={{fn this.delete entry.ruleKind.name}}
              @title={{entry.ruleKind.name}}
            />
          {{/if}}
        {{/each}}

        {{#each this.payload.orphans as |orphan|}}
          <UnknownRuleCard
            @onDelete={{fn this.delete orphan.rule_kind}}
            @title={{orphan.rule_kind}}
          />
        {{/each}}
      </div>

      <AdminConfigAreaCard
        class="admin-mcp-content-restrictions__help"
        @heading="admin.config.mcp.content_restrictions.help.title"
      >
        <:content>
          <p>{{i18n "admin.config.mcp.content_restrictions.help.scope"}}</p>
          <p>{{i18n "admin.config.mcp.content_restrictions.help.tools"}}</p>
          <p>{{i18n "admin.config.mcp.content_restrictions.help.copies"}}</p>
          <p>{{i18n
              "admin.config.mcp.content_restrictions.help.responders"
            }}</p>
          <p>{{i18n "admin.config.mcp.content_restrictions.help.guards"}}</p>
        </:content>
      </AdminConfigAreaCard>
    </div>
  </template>
}
