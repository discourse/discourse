import { action } from "@ember/object";
import StartPostingOption from "discourse/components/admin-onboarding/start-posting-option";
import { service } from "discourse/lib/service";
import ModalService from "discourse/services/modal";

export default class PredefinedTopicsOption extends StartPostingOption {
  @service(() => ModalService) modal;

  name = "predefined-option";
  title = "admin_onboarding_banner.start_posting.predefined_topics";
  body = "admin_onboarding_banner.start_posting.predefined_topics_description";

  @action
  onSelect() {
    this.modal.show(
      () =>
        import("discourse/components/admin-onboarding/modal/predefined-topics-options")
    );
  }
}
