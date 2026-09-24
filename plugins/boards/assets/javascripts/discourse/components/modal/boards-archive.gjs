import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { trustHTML } from "@ember/template";
import Form from "discourse/components/form";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import getURL from "discourse/lib/get-url";
import DModal from "discourse/ui-kit/d-modal";
import { i18n } from "discourse-i18n";

export default class BoardsArchive extends Component {
  @service messageBus;

  formData = { slug: "" };
  currentlyArchived = this.args.model.board.archived;

  get isUnarchive() {
    return this.currentlyArchived;
  }

  get title() {
    return i18n(
      this.isUnarchive
        ? "boards.board.unarchive_board"
        : "boards.board.archive_board"
    );
  }

  get message() {
    if (this.isUnarchive) {
      return i18n(
        this.args.model.board.old_slug_used
          ? "boards.board.unarchive_slug_required"
          : "boards.board.confirm_unarchive"
      );
    }
    return trustHTML(
      i18n("boards.board.confirm_archive", { boards_url: getURL("/boards") })
    );
  }

  @action
  async submit(data) {
    const board = this.args.model.board;
    const actionName = this.isUnarchive ? "unarchive" : "archive";
    try {
      const result = await ajax(
        `/boards/api/boards/${board.id}/${actionName}`,
        {
          type: "POST",
          data: {
            client_id: this.messageBus.clientId,
            ...(this.isUnarchive ? { slug: data.slug } : {}),
          },
        }
      );
      await this.args.model.onSuccess(result.board);
      this.args.closeModal();
    } catch (error) {
      if (this.isUnarchive) {
        const result = await ajax(`/boards/api/boards/${board.id}.json`).catch(
          () => null
        );
        if (result?.board) {
          Object.assign(board, result.board);
        }
      }
      popupAjaxError(error);
    }
  }

  <template>
    <DModal
      class="discourse-boards-archive-modal"
      @closeModal={{@closeModal}}
      @inline={{@inline}}
      @title={{this.title}}
    >
      <:body>
        <Form @data={{this.formData}} @onSubmit={{this.submit}} as |form|>
          <p>{{this.message}}</p>
          {{#if this.isUnarchive}}
            {{#if @model.board.old_slug_used}}
              <form.Field
                @name="slug"
                @required={{true}}
                @title={{i18n "boards.manage.slug"}}
                @type="input"
                as |field|
              >
                <field.Control />
              </form.Field>
            {{/if}}
          {{/if}}
          <form.Actions>
            <form.Submit @label="confirm_button" />
            <form.Button @action={{@closeModal}} @label="cancel" />
          </form.Actions>
        </Form>
      </:body>
    </DModal>
  </template>
}
