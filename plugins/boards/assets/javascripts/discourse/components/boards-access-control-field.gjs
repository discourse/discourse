import Component from "@glimmer/component";
import DAccessControlField from "discourse/ui-kit/d-access-control-field";
import { i18n } from "discourse-i18n";
import { boardPermissionOptions } from "../lib/boards-access-control.js";

export default class BoardsAccessControlField extends Component {
  get aclTarget() {
    return {
      type: "Boards::Board",
      key: "Boards::Board",
      id: this.args.boardId,
      name: i18n("boards.manage.board"),
    };
  }

  <template>
    <DAccessControlField
      @aclTarget={{this.aclTarget}}
      @canManageOwners={{@canManageOwners}}
      @description={{@description}}
      @form={{@form}}
      @isNew={{@isNew}}
      @name={{@name}}
      @onAccessLossConfirmed={{@onAccessLossConfirmed}}
      @onChange={{@onChange}}
      @onSet={{@onSet}}
      @showOptional={{@showOptional}}
      @title={{@title}}
      @transformPermissionOptions={{boardPermissionOptions}}
      @validation={{@validation}}
    />
  </template>
}
