import Controller from "@ember/controller";
import SettingsFilter from "admin/mixins/settings-filter";

export default class AdminBackupsSettingsController extends Controller.extend(
  SettingsFilter
) {}
