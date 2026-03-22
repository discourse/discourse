import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { isBlank } from "@ember/utils";
import ChooseTopic from "discourse/components/choose-topic";
import DModal from "discourse/components/d-modal";
import Form from "discourse/components/form";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { not } from "discourse/truth-helpers";
import { i18n } from "discourse-i18n";

export default class TestIntegration extends Component {
  @tracked flash;
  @tracked flashType = "success";
  @tracked topicId = null;

  @action
  newTopicSelected(topic) {
    this.topicId = topic?.id;
  }

  @action
  async send() {
    try {
      await ajax("/admin/plugins/discourse-chat-integration/test", {
        data: {
          channel_id: this.args.model.channel.id,
          topic_id: this.topicId,
        },
        type: "POST",
      });

      this.flash = i18n("chat_integration.test_modal.success");
      this.flashType = "success";
    } catch (e) {
      popupAjaxError(e);
    }
  }

  get canSend() {
    return !isBlank(this.topicId);
  }

  <template>
    <DModal
      @title={{i18n "chat_integration.test_modal.title"}}
      @closeModal={{@closeModal}}
      @flash={{this.flash}}
      @flashType={{this.flashType}}
      id="chat-integration-test-modal"
      class="chat-integration-modal"
    >
      <:body>
        <Form as |form|>
          <form.Field
            @name="topicId"
            @title={{i18n "chat_integration.test_modal.topic"}}
            @format="full"
            as |field|
          >
            <field.Custom>
              <ChooseTopic
                @topicChangedCallback={{this.newTopicSelected}}
                @selectedTopicId={{this.topicId}}
              />
            </field.Custom>
          </form.Field>

          <form.Actions>
            <form.Button
              @label="chat_integration.test_modal.send"
              @action={{this.send}}
              @disabled={{not this.canSend}}
              class="btn-primary"
              id="send-test"
            />
            <form.Button
              @label="chat_integration.test_modal.close"
              @action={{@closeModal}}
              class="btn-default"
            />
          </form.Actions>
        </Form>
      </:body>
    </DModal>
  </template>
}
