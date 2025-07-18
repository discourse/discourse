import Component from "@ember/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { classNames, tagName } from "@ember-decorators/component";
import ShowUserNotes from "../../components/show-user-notes";
import { showUserNotes } from "../../lib/user-notes";

@tagName("li")
@classNames("user-profile-controls-outlet", "show-notes-on-profile")
export default class ShowNotesOnProfile extends Component {
  static shouldRender(args, context) {
    const { siteSettings, currentUser } = context;
    return siteSettings.user_notes_enabled && currentUser && currentUser.staff;
  }

  @service store;

  init() {
    super.init(...arguments);
    const { model } = this;
    this.set(
      "userNotesCount",
      model.user_notes_count || model.get("custom_fields.user_notes_count") || 0
    );
  }

  @action
  showUserNotes() {
    const user = this.model;
    showUserNotes(this.store, user.id, (count) =>
      this.set("userNotesCount", count)
    );
  }

  <template>
    <ShowUserNotes
      @show={{this.showUserNotes}}
      @count={{this.userNotesCount}}
    />
  </template>
}
