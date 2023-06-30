import Component from "@glimmer/component";
import { action } from "@ember/object";
import { tracked } from "@glimmer/tracking";
import { inject as service } from "@ember/service";

export default class SecondFactorEdit extends Component {
  @service modal;

  @tracked loading = false;

  @action
  editSecondFactor() {
    this.loading = true;
    this.args.model.user
      .updateSecondFactor(
        this.args.model.secondFactor.id,
        this.args.model.secondFactor.name,
        false,
        this.args.model.secondFactor.method
      )
      .then((response) => {
        if (response.error) {
          return;
        }
        this.args.model.markDirty();
      })
      .catch((error) => {
        this.modal.close();
        this.args.model.onError(error);
      })
      .finally(() => {
        this.loading = false;
        this.modal.close();
      });
  }
}
