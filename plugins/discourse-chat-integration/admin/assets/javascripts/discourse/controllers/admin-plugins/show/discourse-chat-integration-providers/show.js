import { tracked } from "@glimmer/tracking";
import Controller from "@ember/controller";
import { action } from "@ember/object";
import { service } from "@ember/service";
import ChannelErrorModal from "../../../../components/modal/channel-error";
import EditRuleModal from "../../../../components/modal/edit-rule";
import TestModal from "../../../../components/modal/test-integration";

export default class DiscourseChatIntegrationProvidersShow extends Controller {
  @service modal;
  @service store;

  @tracked showNewChannelForm = false;
  @tracked newChannel = null;

  get anyErrors() {
    let anyErrors = false;

    this.model.channels.content.forEach((channel) => {
      if (channel.error_key) {
        anyErrors = true;
      }
    });

    return anyErrors;
  }

  initNewChannel() {
    this.newChannel = this.store.createRecord("channel", {
      provider: this.model.provider.id,
      data: {},
    });
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
    this.initNewChannel();
    this.showNewChannelForm = true;
  }

  @action
  cancelNewChannel() {
    this.showNewChannelForm = false;
    this.newChannel = null;
  }

  @action
  onChannelSaved() {
    this.showNewChannelForm = false;
    this.initNewChannel();
    this.refresh();
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
