import Component from "@glimmer/component";
import { array } from "@ember/helper";
import { action } from "@ember/object";
import DAccessControlField from "discourse/ui-kit/d-access-control-field";
import { i18n } from "discourse-i18n";

export default class BoardsAccessControlField extends Component {
  get aclTarget() {
    return {
      type: "Boards::Board",
      key: "Boards::Board",
      id: this.args.boardId,
      name: i18n("boards.manage.board"),
    };
  }

  @action
  transformPermissionOptions(options) {
    const viewOption = options.find((option) => option.id === "view");
    viewOption.description = i18n(
      "boards.manage.board_access_permission_viewer_description"
    );

    const editOption = options.find((option) => option.id === "edit");
    editOption.description = i18n(
      "boards.manage.board_access_permission_editor_description"
    );

    options.push({
      id: "manage",
      level: 3,
      name: i18n("boards.manage.board_access_permission_manager"),
      description: i18n(
        "boards.manage.board_access_permission_manager_description"
      ),
    });

    return options;
  }

  <template>
    <DAccessControlField
      @aclTarget={{this.aclTarget}}
      @description={{@description}}
      @form={{@form}}
      @mustHavePermissions={{array "manage"}}
      @name={{@name}}
      @onAccessLossConfirmed={{@onAccessLossConfirmed}}
      @onChange={{@onChange}}
      @onSet={{@onSet}}
      @showOptional={{@showOptional}}
      @title={{@title}}
      @transformPermissionOptions={{this.transformPermissionOptions}}
      @validation={{@validation}}
    />
  </template>
}
