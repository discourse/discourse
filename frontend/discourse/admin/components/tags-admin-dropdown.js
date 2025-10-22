import { action, computed } from "@ember/object";
import { service } from "@ember/service";
import { classNames } from "@ember-decorators/component";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { i18n } from "discourse-i18n";
import TagUpload from "admin/components/modal/tag-upload";
import DropdownSelectBoxComponent from "select-kit/components/dropdown-select-box";
import {
  pluginApiIdentifiers,
  selectKitOptions,
} from "select-kit/components/select-kit";

@classNames("tags-admin-dropdown")
@selectKitOptions({
  icons: ["wrench", "caret-down"],
  showFullTitle: false,
})
@pluginApiIdentifiers("tags-admin-dropdown")
export default class TagsAdminDropdown extends DropdownSelectBoxComponent {
  @service router;
  @service modal;
  @service dialog;

  actionsMapping = {
    manageGroups: () => this.router.transitionTo("tagGroups"),
    uploadTags: () => this.modal.show(TagUpload),
    deleteUnusedTags: () => this.send("deleteUnused"),
  };

  @computed
  get content() {
    return [
      {
        id: "manageGroups",
        name: i18n("tagging.manage_groups"),
        description: i18n("tagging.manage_groups_description"),
        icon: "tags",
      },
      {
        id: "uploadTags",
        name: i18n("tagging.upload"),
        description: i18n("tagging.upload_description"),
        icon: "upload",
      },
      {
        id: "deleteUnusedTags",
        name: i18n("tagging.delete_unused"),
        description: i18n("tagging.delete_unused_description"),
        icon: "trash-can",
      },
    ];
  }

  @action
  onChange(id) {
    this.actionsMapping[id]?.();
  }

  @action
  deleteUnused() {
    ajax("/tags/unused", { type: "GET" })
      .then((result) => {
        const displayN = 20;
        const tags = result["tags"];

        if (tags.length === 0) {
          this.dialog.alert(i18n("tagging.delete_no_unused_tags"));
          return;
        }

        const joinedTags = tags
          .slice(0, displayN)
          .join(i18n("tagging.tag_list_joiner"));
        const more = Math.max(0, tags.length - displayN);

        const tagsString =
          more === 0
            ? joinedTags
            : i18n("tagging.delete_unused_confirmation_more_tags", {
                count: more,
                tags: joinedTags,
              });

        const message = i18n("tagging.delete_unused_confirmation", {
          count: tags.length,
          tags: tagsString,
        });

        this.dialog.deleteConfirm({
          message,
          confirmButtonLabel: "tagging.delete_unused",
          didConfirm: () => {
            return ajax("/tags/unused", { type: "DELETE" })
              .then(() => this.router.refresh())
              .catch(popupAjaxError);
          },
        });
      })
      .catch(popupAjaxError);
  }
}
