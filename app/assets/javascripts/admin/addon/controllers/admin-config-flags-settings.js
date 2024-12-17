import Controller from "@ember/controller";
import SettingsFilter from "admin/mixins/settings-filter";

export default class AdminConfigFlagsSettingsController extends Controller.extend(
  SettingsFilter
) {}
