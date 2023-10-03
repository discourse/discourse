import Component from "@glimmer/component";
import { action } from "@ember/object";
import { tracked } from "@glimmer/tracking";
import { MAX_SECOND_FACTOR_NAME_LENGTH } from "discourse/models/user";

export default class SecondFactorEditSecurityKey extends Component {
  @tracked loading = false;

  maxSecondFactorNameLength = MAX_SECOND_FACTOR_NAME_LENGTH;

  @action
  editSecurityKey() {
    this.loading = true;
    this.args.model.user
      .updateSecurityKey(
        this.args.model.securityKey.id,
        this.args.model.securityKey.name,
        false
      )
      .then((response) => {
        if (response.error) {
          return;
        }
        this.args.model.markDirty();
      })
      .catch((error) => {
        this.args.model.onError(error);
      })
      .finally(() => {
        this.loading = false;
        this.args.closeModal();
      });
  }
}
