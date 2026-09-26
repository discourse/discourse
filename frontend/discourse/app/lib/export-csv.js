import { lookup } from "discourse/lib/service";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { getOwnerWithFallback } from "discourse/lib/get-owner";
import { i18n } from "discourse-i18n";
import DialogService from "discourse/dialog-holder/services/dialog";

function exportEntityByType(type, entity, args) {
  return ajax("/export_csv/export_entity.json", {
    type: "POST",
    data: { entity, args },
  });
}

export function exportUserArchive() {
  const dialog = lookup(getOwnerWithFallback(this), DialogService);
  return exportEntityByType("user", "user_archive")
    .then(function () {
      dialog.alert(i18n("user.download_archive.success"));
    })
    .catch(popupAjaxError);
}

export function exportEntity(entity, args) {
  return exportEntityByType("admin", entity, args);
}
