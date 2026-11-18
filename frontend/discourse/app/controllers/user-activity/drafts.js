import Controller from "@ember/controller";
import { service } from "@ember/service";

export default class UserActivityDraftsController extends Controller {
  @service siteSettings;

  get retentionDays() {
    return this.siteSettings.discarded_drafts_retention_days;
  }
}
