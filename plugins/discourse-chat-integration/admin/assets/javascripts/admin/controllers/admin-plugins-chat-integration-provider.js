import Controller from "@ember/controller";
import { action } from "@ember/object";
import { service } from "@ember/service";
import ChannelErrorModal from "../components/modal/channel-error";
import EditChannelModal from "../components/modal/edit-channel";
import EditRuleModal from "../components/modal/edit-rule";
import TestModal from "../components/modal/test-integration";

export default class AdminPluginsChatIntegrationProvider extends Controller {
  @service modal;
  @service store;

  get anyErrors() {
    let anyErrors = false;

    this.model.channels.forEach((channel) => {
      if (channel.error_key) {
        anyErrors = true;
      }
    });

    return anyErrors;
  }

  async triggerModal(modal, model) {
    await this.modal.show(modal, {
      model: {
        ...model,
        admin: true,
      },
    });

    this.refresh();
  }

  @action
  createChannel() {
    return this.triggerModal(EditChannelModal, {
      channel: this.store.createRecord("channel", {
        provider: this.model.provider.id,
        data: {},
      }),
      provider: this.model.provider,
    });
  }

  @action
  editChannel(channel) {
    return this.triggerModal(EditChannelModal, {
      channel,
      provider: this.model.provider,
    });
  }

  @action
  testChannel(channel) {
    return this.triggerModal(TestModal, { channel });
  }

  @action
  createRule(channel) {
    return this.triggerModal(EditRuleModal, {
      rule: this.store.createRecord("rule", {
        channel_id: channel.id,
        channel,
      }),
      channel,
      provider: this.model.provider,
      groups: this.model.groups,
    });
  }

  @action
  editRuleWithChannel(rule, channel) {
    return this.triggerModal(EditRuleModal, {
      rule,
      channel,
      provider: this.model.provider,
      groups: this.model.groups,
    });
  }

  @action
  showError(channel) {
    return this.triggerModal(ChannelErrorModal, { channel });
  }

  @action
  refresh() {
    this.send("refreshProvider");
  }
}
