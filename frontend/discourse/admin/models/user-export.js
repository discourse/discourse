import { ajax } from "discourse/lib/ajax";
import RestModel from "discourse/models/rest";

export default class UserExport extends RestModel {
  static async findLatest(user_id) {
    const result = await ajax(
      `/export_csv/latest_user_archive/${user_id}.json`
    );
    if (result !== null) {
      return UserExport.create(result.user_export);
    }
  }
}
