import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";

function exportEntityByType(type, entity, args) {
  return ajax("/export_csv/export_entity.json", {
    method: "POST",
    data: { entity, args }
  });
}

export function exportUserArchive() {
  return exportEntityByType("user", "user_archive")
    .then(function() {
      bootbox.alert(I18n.t("user.download_archive.success"));
    })
    .catch(popupAjaxError);
}

export function exportEntity(entity, args) {
  return exportEntityByType("admin", entity, args);
}
