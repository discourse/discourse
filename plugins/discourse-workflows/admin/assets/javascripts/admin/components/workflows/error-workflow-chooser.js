import { classNames } from "@ember-decorators/component";
import { ajax } from "discourse/lib/ajax";
import ComboBoxComponent from "discourse/select-kit/components/combo-box";
import {
  pluginApiIdentifiers,
  selectKitOptions,
} from "discourse/select-kit/components/select-kit";

@classNames("error-workflow-chooser")
@pluginApiIdentifiers("error-workflow-chooser")
@selectKitOptions({
  filterable: true,
  allowAny: false,
})
export default class ErrorWorkflowChooser extends ComboBoxComponent {
  nameProperty = "name";
  valueProperty = "id";

  select(value, item) {
    this.set("content", [item]);
    return super.select(value, item);
  }

  async search(filter) {
    const result = await ajax(
      "/admin/plugins/discourse-workflows/workflows.json",
      {
        data: {
          filter,
          trigger_type: "error",
          exclude_id: this.selectKit.options.excludeWorkflowId,
        },
      }
    );

    return (result.workflows || []).map((wf) => ({
      id: wf.id,
      name: wf.name,
    }));
  }
}
