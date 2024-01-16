import Service from "@ember/service";
import { ajax } from "discourse/lib/ajax";

export default class ThemeStore extends Service {
  store(themeId, tableName, json) {
    ajax(`/admin/themes/${themeId}/store`, {
      type: "PUT",
      data: {
        table_name: tableName,
        json: JSON.stringify(json),
      },
    });
  }

  async fetch(themeId, tableName) {
    const result = await ajax(`/admin/themes/${themeId}/store`, {
      type: "GET",
      data: {
        table_name: tableName,
      },
    });

    return result;
  }
}
