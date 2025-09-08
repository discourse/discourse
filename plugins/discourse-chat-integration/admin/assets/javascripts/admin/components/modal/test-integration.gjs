import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { not } from "truth-helpers";
import ChooseTopic from "discourse/components/choose-topic";
import ConditionalLoadingSpinner from "discourse/components/conditional-loading-spinner";
import DButton from "discourse/components/d-button";
import DModal from "discourse/components/d-modal";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { i18n } from "discourse-i18n";

export default class TestIntegration extends Component {
  @tracked loading = false;
  @tracked flash;
  @tracked topicId;

  @action
  async send() {
    this.loading = true;

    try {
      await ajax("/admin/plugins/chat-integration/test", {
        data: {
          channel_id: this.args.model.channel.id,
          topic_id: this.topicId,
        },
        type: "POST",
      });

      this.loading = false;
      this.flash = i18n("chat_integration.test_modal.success");
    } catch (e) {
      popupAjaxError(e);
    }
  }

  @action
  newTopicSelected(topic) {
    this.topicId = topic?.id;
  }

  <template>
    <DModal
      {{on "submit" this.send}}
      @title={{i18n "chat_integration.test_modal.title"}}
      @closeModal={{@closeModal}}
      @flash={{this.flash}}
      @flashType="success"
      @tagName="form"
      id="chat_integration_test_modal"
    >
      <:body>
        <table>
          <tbody>
            <tr class="input">
              <td class="label">
                <label for="channel">
                  {{i18n "chat_integration.test_modal.topic"}}
                </label>
              </td>
              <td>
                <ChooseTopic
                  @topicChangedCallback={{this.newTopicSelected}}
                  @selectedTopicId={{this.topicId}}
                />
              </td>
            </tr>
          </tbody>
        </table>
      </:body>

      <:footer>
        <ConditionalLoadingSpinner @condition={{this.loading}}>
          <DButton
            @action={{this.send}}
            @label="chat_integration.test_modal.send"
            @disabled={{not this.topicId}}
            type="submit"
            id="send-test"
            class="btn-primary btn-large"
          />
          <DButton
            @action={{@closeModal}}
            @label="chat_integration.test_modal.close"
            class="btn-large"
          />
        </ConditionalLoadingSpinner>
      </:footer>
    </DModal>
  </template>
}
