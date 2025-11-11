import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import ShowUserNotes from "../../components/show-user-notes";
import { showUserNotes } from "../../lib/user-notes";

export default class AddUserNotesButton extends Component {
  static shouldRender(args, { siteSettings, currentUser }) {
    return siteSettings.user_notes_enabled && currentUser?.staff;
  }

  @service store;

  @tracked
  userNotesCount =
    this.args.model.user_notes_count ||
    this.args.model.custom_fields?.user_notes_count ||
    0;

  @action
  showUserNotes() {
    showUserNotes(
      this.store,
      this.args.model.id,
      (count) => (this.userNotesCount = count)
    );
  }

  <template>
    <ShowUserNotes
      @show={{this.showUserNotes}}
      @count={{this.userNotesCount}}
    />
  </template>
}
