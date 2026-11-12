import { ajax } from "discourse/lib/ajax";
import RestModel, { type RestPayload } from "discourse/models/rest";

/** Latest user archive; the serializer sends an empty record until the upload is attached. */
export interface UserExportFields {
  id?: number;
  filename?: string;
  uri?: string;
  filesize?: number;
  extension?: string | null;
  retain_hours?: number;
  human_filesize?: string;
}

// eslint-disable-next-line @typescript-eslint/no-empty-object-type, @typescript-eslint/no-unsafe-declaration-merging
export default interface UserExport extends UserExportFields {}

// eslint-disable-next-line @typescript-eslint/no-unsafe-declaration-merging
export default class UserExport extends RestModel {
  static async findLatest(
    user_id: number | string
  ): Promise<UserExport | undefined> {
    const result = await ajax<{
      user_export: UserExportFields & RestPayload;
    } | null>(`/export_csv/latest_user_archive/${user_id}.json`);
    if (result !== null) {
      return UserExport.create(result.user_export);
    }
  }
}
