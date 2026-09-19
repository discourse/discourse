import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { isBlank } from "@ember/utils";
import ChooseTopic from "discourse/components/choose-topic";
import Form from "discourse/components/form";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { not } from "discourse/truth-helpers";
import DModal from "discourse/ui-kit/d-modal";
import { i18n } from "discourse-i18n";

export default class TestIntegration extends Component {
  @tracked flash;
  @tracked flashType = "success";
  @tracked topicId = null;

  get canSend() {
    return !isBlank(this.topicId);
  }

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

  <template>
    <DModal
      class="chat-integration-modal"
      id="chat-integration-test-modal"
      @closeModal={{@closeModal}}
      @flash={{this.flash}}
      @flashType={{this.flashType}}
      @title={{i18n "chat_integration.test_modal.title"}}
    >
      <:body>
        <Form as |form|>
          <form.Field
            @format="full"
            @name="topicId"
            @title={{i18n "chat_integration.test_modal.topic"}}
            @type="custom"
            as |field|
          >
            <field.Control>
              <ChooseTopic
                @selectedTopicId={{this.topicId}}
                @topicChangedCallback={{this.newTopicSelected}}
              />
            </field.Control>
          </form.Field>

          <form.Actions>
            <form.Button
              class="btn-primary"
              id="send-test"
              @action={{this.send}}
              @disabled={{not this.canSend}}
              @label="chat_integration.test_modal.send"
            />
            <form.Button
              class="btn-default"
              @action={{@closeModal}}
              @label="chat_integration.test_modal.close"
            />
          </form.Actions>
        </Form>
      </:body>
    </DModal>
  </template>
}
