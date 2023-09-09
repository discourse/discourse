import Component from "@glimmer/component";
import { action } from "@ember/object";
import { ajax } from "discourse/lib/ajax";
import { tracked } from "@glimmer/tracking";

export default class RenamePasskey extends Component {
  @tracked passkeyName;

  constructor() {
    super(...arguments);
    this.passkeyName = this.args.model.name;
  }

  @action
  saveRename() {
    ajax(`/u/rename_passkey/${this.args.model.id}`, {
      type: "POST",
      data: {
        name: this.passkeyName,
      },
    }).then(() => {
      window.location.reload();
    });
  }
}
