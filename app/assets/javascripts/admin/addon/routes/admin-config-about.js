import Route from "@ember/routing/route";
import { ajax } from "discourse/lib/ajax";

export default class AdminConfigAboutRoute extends Route {
  model() {
    return ajax("/admin/config/site_settings.json", {
      data: {
        filter_names: [
          "title",
          "site_description",
          "extended_site_description",
          "short_site_description",
          "about_banner_image",
          "community_owner",
          "contact_email",
          "contact_url",
          "site_contact_username",
          "site_contact_group_name",
          "company_name",
          "governing_law",
          "city_for_disputes",
        ],
      },
    });
  }
}
