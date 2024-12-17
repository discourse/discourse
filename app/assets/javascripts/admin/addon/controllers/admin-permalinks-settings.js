import Controller from "@ember/controller";
import SettingsFilter from "admin/mixins/settings-filter";

export default class AdminPermalinksSettingsController extends Controller.extend(
  SettingsFilter
) {}
