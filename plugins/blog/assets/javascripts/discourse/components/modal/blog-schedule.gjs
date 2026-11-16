import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import Form from "discourse/components/form";
import DModal from "discourse/ui-kit/d-modal";
import { i18n } from "discourse-i18n";

export default class BlogSchedule extends Component {
  @tracked busy = false;

  @action
  async schedule(data) {
    this.busy = true;
    try {
      if (await this.args.model.onSchedule(data.scheduled_at)) {
        this.args.closeModal();
      }
    } finally {
      this.busy = false;
    }
  }

  <template>
    <DModal
      class="blog-schedule"
      @closeModal={{@closeModal}}
      @title={{i18n "blog.panel.schedule_title"}}
    >
      <:body>
        <p class="blog-schedule__notice">{{i18n
            "blog.panel.schedule_notice"
          }}</p>
        <Form @onSubmit={{this.schedule}} as |form|>
          <form.Field
            @description={{i18n "blog.panel.schedule_time_hint"}}
            @format="full"
            @name="scheduled_at"
            @title={{i18n "blog.panel.schedule_time"}}
            @type="input"
            @validation="required"
            as |field|
          ><field.Control @type="datetime-local" /></form.Field>
          <form.Actions>
            <form.Submit
              @disabled={{this.busy}}
              @label="blog.panel.schedule_submit"
            />
          </form.Actions>
        </Form>
      </:body>
    </DModal>
  </template>
}
