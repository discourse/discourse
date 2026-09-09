import Component from "@glimmer/component";
import { fn, hash } from "@ember/helper";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { service } from "@ember/service";
import Form from "discourse/components/form";
import { ajax } from "discourse/lib/ajax";
import { USER_OPTION_COMPOSITION_MODES } from "discourse/lib/constants";
import EmailGroupUserChooser from "discourse/select-kit/components/email-group-user-chooser";
import { not } from "discourse/truth-helpers";
import DButton from "discourse/ui-kit/d-button";
import DModal from "discourse/ui-kit/d-modal";
import { i18n } from "discourse-i18n";
import BoardsEditableTitle from "../boards-editable-title";

export default class BoardsCardDetail extends Component {
  @service siteSettings;
  @service currentUser;

  get canWrite() {
    return this.args.model.canWrite;
  }

  get formData() {
    const card = this.args.model.card;
    const assignedTo = card.assigned_to;
    return {
      title: card.title || "",
      notes: card.notes || "",
      tags: [...(card.tags || [])],
      assigned_to: assignedTo ? [assignedTo.username || assignedTo.name] : [],
    };
  }

  get isNew() {
    return !!this.args.model.isNew;
  }

  @action
  onAssignedChanged(field, value) {
    field.set(value || []);
  }

  @action
  async save(data) {
    const tagIds = [];
    const tagNames = [];
    for (const tag of data.tags || []) {
      if (Number.isInteger(tag.id) && tag.id > 0) {
        tagIds.push(tag.id);
      } else if (typeof tag.id === "string" && tag.id.length > 0) {
        tagNames.push(tag.id);
      }
    }

    const updates = {
      title: data.title.trim(),
      notes: data.notes,
      tag_ids:
        !this.isNew && !tagIds.length && !tagNames.length ? [""] : tagIds,
      tag_names: tagNames,
      assigned_to_name: data.assigned_to[0] || null,
    };
    try {
      if (this.isNew) {
        await this.args.model.onCreateCard(updates);
      } else {
        await this.args.model.onUpdateCard(this.args.model.card.id, updates);
      }
      this.args.closeModal();
    } catch {
      // modal stays open — popupAjaxError already handles the error
    }
  }

  @action
  viewCard() {
    if (!this.currentUser) {
      return;
    }

    if (this.isNew) {
      return;
    }

    ajax(
      `/boards/api/boards/${this.args.model.card.board_id}/cards/${this.args.model.card.id}/view`,
      { method: "POST" }
    ).catch(() => {
      // No error message should be shown if this fails,
      // it's purely for history logging.
    });
  }

  <template>
    <DModal
      class="discourse-boards-card-detail-modal"
      @closeModal={{@closeModal}}
      @hideHeader={{true}}
      @submitOnEnter={{false}}
      {{didInsert this.viewCard}}
    >
      <:body>
        <Form @data={{this.formData}} @onSubmit={{this.save}} as |form data|>
          <BoardsEditableTitle
            @disabled={{not this.canWrite}}
            @form={{form}}
            @name="title"
            @placeholder={{i18n "boards.board.title_placeholder"}}
            @showClose={{false}}
            @title={{i18n "boards.board.title"}}
          />
          <form.Section>
            <form.Field
              @disabled={{not this.canWrite}}
              @format="max"
              @name="notes"
              @title={{i18n "boards.board.notes"}}
              @type="composer"
              as |field|
            >
              <field.Control
                @forceEditorMode={{USER_OPTION_COMPOSITION_MODES.rich}}
                @height={{300}}
              />
            </form.Field>
            <form.Field
              @disabled={{not this.canWrite}}
              @format="max"
              @name="tags"
              @title={{i18n "boards.board.tags"}}
              @type="tag-chooser"
              as |field|
            >
              <field.Control
                @allowCreate={{true}}
                @prioritizeRecentTags={{true}}
              />
            </form.Field>

            {{#if this.siteSettings.assign_enabled}}
              <form.Field
                @disabled={{not this.canWrite}}
                @format="max"
                @name="assigned_to"
                @title={{i18n "boards.board.assigned_to"}}
                @type="custom"
                as |field|
              >
                <field.Control>
                  <EmailGroupUserChooser
                    @disabled={{not this.canWrite}}
                    @onChange={{fn this.onAssignedChanged field}}
                    @options={{hash maximum=1 excludeCurrentUser=false}}
                    @value={{data.assigned_to}}
                  />
                </field.Control>
              </form.Field>
            {{/if}}
          </form.Section>

          <form.Actions>
            {{#if this.canWrite}}
              <form.Submit />
            {{/if}}
            <form.Button
              class="btn-flat d-modal-cancel"
              @action={{@closeModal}}
              @label="cancel"
            />
          </form.Actions>
        </Form>

        <DButton
          class="btn-flat discourse-boards-card-detail-modal__close"
          @action={{@closeModal}}
          @ariaLabel="modal.close"
          @icon="xmark"
          @title="modal.close"
        />
      </:body>
    </DModal>
  </template>
}
