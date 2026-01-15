import { action } from "@ember/object";
import { getOwner } from "@ember/owner";
import Group from "discourse/models/group";
import DiscourseRoute from "discourse/routes/discourse";

export default class DiscourseChatIntegrationProvidersShow extends DiscourseRoute {
  async model(params) {
    const providers = this.modelFor(
      "adminPlugins.show.discourse-chat-integration-providers"
    );

    const [channels, groups] = await Promise.all([
      this.store.findAll("channel", { provider: params.provider }),
      Group.findAll(),
    ]);

    const provider = providers.content.find(
      (item) => item.id === params.provider
    );

    const enabledFilters =
      getOwner(this).lookup("model:rule").possible_filters_id;

    channels.content.forEach((channel) => {
      channel.set(
        "rules",
        channel.rules
          .filter((rule) => enabledFilters.includes(rule.filter))
          .map((rule) => {
            rule = this.store.createRecord("rule", rule);
            rule.set("channel", channel);
            return rule;
          })
      );
    });

    return {
      channels,
      provider,
      providers,
      groups,
    };
  }

  serialize(model) {
    return { provider: model.provider.id };
  }

  @action
  refreshProvider() {
    this.refresh();
  }
}
