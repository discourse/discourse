import { setOwner } from "@ember/owner";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";

export default class BoostFlag {
  constructor(owner) {
    setOwner(this, owner);
  }

  title() {
    return "flagging.title";
  }

  customSubmitLabel() {
    return "flagging.notify_action";
  }

  submitLabel() {
    return "discourse_boosts.flagging.action";
  }

  targetsTopic() {
    return false;
  }

  editable() {
    return false;
  }

  flagsAvailable(flagModal) {
    return flagModal.site.flagTypes.filter((flag) => {
      return (
        this.availableFlags.includes(flag.name_key) &&
        flag.applies_to.includes("DiscourseBoosts::Boost")
      );
    });
  }

  async create(flagModal) {
    flagModal.args.closeModal();

    try {
      await ajax(`/discourse-boosts/boosts/${this.boostId}/flags`, {
        type: "POST",
        data: {
          flag_type_id: flagModal.selected.id,
        },
      });
    } catch (error) {
      popupAjaxError(error);
    }
  }
}
