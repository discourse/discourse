import { action } from "@ember/object";
import { service } from "@ember/service";
import PredefinedTopicsOptionsModal from "discourse/components/admin-onboarding/modal/predefined-topics-options";
import StartPostingOption from "discourse/components/admin-onboarding/start-posting-option";

export default class PredefinedTopicsOption extends StartPostingOption {
  @service modal;

  name = "predefined-option";
  title = "admin_onboarding_banner.start_posting.predefined_topics";
  body = "admin_onboarding_banner.start_posting.predefined_topics_description";
  actionLabel = "admin_onboarding_banner.start_posting.use_predefined";

  @action
  onSelect() {
    this.modal.show(PredefinedTopicsOptionsModal);
  }
}
