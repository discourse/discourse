import Component from "@glimmer/component";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { applyValueTransformer } from "discourse/lib/transformer";
import DropdownSelectBox from "discourse/select-kit/components/dropdown-select-box";
import { i18n } from "discourse-i18n";

const BOT_OPTION = {
  id: "bot",
  icon: "robot",
  label: "admin.users.bots.new_options.bot.label",
  description: "admin.users.bots.new_options.bot.description",
  route: "adminBotsNew",
};

/**
 * The "New bot" action for the bots list. Becomes a dropdown explaining each
 * path when other bot-creating flows are registered via `admin-new-bot-options`.
 */
export default class AdminNewBotButton extends Component {
  @service router;

  get options() {
    return applyValueTransformer("admin-new-bot-options", [BOT_OPTION]);
  }

  get hasChoices() {
    return this.options.length > 1;
  }

  get content() {
    return this.options.map((option) => ({
      id: option.id,
      name: i18n(option.label),
      description: i18n(option.description),
      icon: option.icon,
    }));
  }

  @action
  select(id) {
    const option = this.options.find((o) => o.id === id);
    this.router.transitionTo(option.route, ...(option.routeModels ?? []), {
      queryParams: option.queryParams ?? {},
    });
  }

  <template>
    {{#if this.hasChoices}}
      <@actions.Wrapped>
        <DropdownSelectBox
          class="admin-users__subheader-new-bot"
          @content={{this.content}}
          @onChange={{this.select}}
          @options={{hash
            showCaret=true
            translatedNone=(i18n "admin.users.bots.new")
            customStyle=true
            btnCustomClasses="btn-primary btn-small"
          }}
        />
      </@actions.Wrapped>
    {{else}}
      <@actions.Primary
        class="admin-users__subheader-new-bot"
        @label="admin.users.bots.new"
        @route="adminBotsNew"
      />
    {{/if}}
  </template>
}
