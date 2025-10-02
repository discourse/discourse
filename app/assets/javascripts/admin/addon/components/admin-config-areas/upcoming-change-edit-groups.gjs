import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DModal from "discourse/components/d-modal";
import Form from "discourse/components/form";
import GroupSelector from "discourse/components/group-selector";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import Group from "discourse/models/group";
import { i18n } from "discourse-i18n";

export default class UpcomingChangeEditGroups extends Component {
  @service currentUser;

  @action
  groupFinder(term) {
    return Group.findAll({ term, ignore_automatic: false });
  }

  @action
  async handleSubmit(data) {
    try {
      await ajax("/admin/config/upcoming-changes/groups", {
        type: "PUT",
        data: {
          setting: this.args.model.setting,
          groups: data.groups.split(","),
        },
      });
    } catch (err) {
      popupAjaxError(err);
    }

    this.args.closeModal(data);
  }

  get formData() {
    return {
      groups: this.args.model.groups,
    };
  }

  <template>
    <DModal
      @closeModal={{@closeModal}}
      @title={{i18n "admin.upcoming_changes.edit_groups"}}
      class="upcoming-change-edit-groups-modal"
    >
      <:body>
        <Form @onSubmit={{this.handleSubmit}} @data={{this.formData}} as |form|>
          <form.Field
            @name="groups"
            @title={{i18n "admin.upcoming_changes.opt_in_groups"}}
            @helpText={{i18n
              "admin.upcoming_changes.opt_in_groups_instructions"
            }}
            @format="full"
            as |field|
          >
            <field.Custom>
              <GroupSelector
                @groupFinder={{this.groupFinder}}
                @groupNames={{field.value}}
                @onChange={{field.set}}
                @placeholderKey="admin.upcoming_changes.select_groups"
              />
            </field.Custom>
          </form.Field>

          <form.Actions>
            <form.Submit />
            <form.Button
              @action={{@closeModal}}
              @label="cancel_value"
              class="btn-flat"
            />
          </form.Actions>
        </Form>
      </:body>
    </DModal>
  </template>
}
