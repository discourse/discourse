import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { Input } from "@ember/component";
import DButton from "discourse/components/d-button";
import DModal from "discourse/components/d-modal";
import htmlSafe from "discourse/helpers/html-safe";
import { i18n } from "discourse-i18n";

export default class DeletePostsConfirmation extends Component {
  @tracked value;

  get text() {
    return i18n("admin.user.delete_posts.confirmation.text", {
      username: this.args.model.user.username,
      post_count: this.args.model.user.post_count,
    });
  }

  get deleteDisabled() {
    return !this.value || this.text !== this.value;
  }

  <template>
    <DModal
      @title={{htmlSafe
        (i18n
          "admin.user.delete_posts.confirmation.title"
          username=@model.user.username
        )
      }}
      @closeModal={{@closeModal}}
    >
      <:body>
        <p>{{htmlSafe
            (i18n
              "admin.user.delete_posts.confirmation.description"
              username=@model.user.username
              post_count=@model.user.post_count
              text=this.text
            )
          }}</p>
        <Input @type="text" @value={{this.value}} />
      </:body>
      <:footer>
        <DButton
          class="btn-danger"
          @action={{@model.deleteAllPosts}}
          @icon="trash-can"
          @disabled={{this.deleteDisabled}}
          @translatedLabel={{i18n
            "admin.user.delete_posts.confirmation.delete"
            username=@model.user.username
          }}
        />
        <DButton
          @action={{@closeModal}}
          @label="admin.user.delete_posts.confirmation.cancel"
        />
      </:footer>
    </DModal>
  </template>
}
