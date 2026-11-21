import Component from "@glimmer/component";
import { cached, tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import Form from "discourse/components/form";
import { ajax } from "discourse/lib/ajax";
import { extractError } from "discourse/lib/ajax-error";
import DModal from "discourse/ui-kit/d-modal";
import DModalCancel from "discourse/ui-kit/d-modal-cancel";
import { i18n } from "discourse-i18n";

export default class EditTopicFooterNotice extends Component {
  @tracked saving = false;
  @tracked error;

  @cached
  get data() {
    return { notice: this.args.model.footer_staff_notice ?? "" };
  }

  @action
  async save({ notice }) {
    this.saving = true;
    this.error = null;
    const topic = this.args.model;

    try {
      const result = await ajax(`/t/${topic.id}/footer_staff_notice`, {
        type: "PUT",
        data: { notice: notice ?? "" },
      });
      topic.set("footer_staff_notice", result.footer_staff_notice);
      this.args.closeModal();
    } catch (error) {
      this.error = extractError(error);
    } finally {
      this.saving = false;
    }
  }

  <template>
    <DModal
      class="edit-topic-footer-notice"
      @closeModal={{@closeModal}}
      @flash={{this.error}}
      @flashType="error"
      @title={{i18n "topic.footer_staff_notice.title"}}
    >
      <:body>
        <Form @data={{this.data}} @onSubmit={{this.save}} as |form|>
          <form.Field
            @description={{i18n "topic.footer_staff_notice.description"}}
            @format="full"
            @name="notice"
            @title={{i18n "topic.footer_staff_notice.message"}}
            @type="textarea"
            @validation="length:0,1000"
            as |field|
          >
            <field.Control maxlength="1000" />
          </form.Field>

          <form.Actions>
            <form.Submit @disabled={{this.saving}} @label="save" />
            <DModalCancel @close={{@closeModal}} />
          </form.Actions>
        </Form>
      </:body>
    </DModal>
  </template>
}
