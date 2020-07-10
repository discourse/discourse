import I18n from "I18n";
import Controller from "@ember/controller";
import { action } from "@ember/object";
import { classify } from "@ember/string";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import ModalFunctionality from "discourse/mixins/modal-functionality";
import discourseComputed from "discourse-common/utils/decorators";

export default Controller.extend(ModalFunctionality, {
  model: null,
  groupedBy: null,
  highlightedOption: null,
  displayMode: "percentage",

  @discourseComputed("model.groupableUserFields")
  groupableUserFields(fields) {
    return fields.map(field => ({
      id: field,
      label: transformUserFieldToLabel(field)
    }));
  },

  @discourseComputed("model.poll.options")
  totalVotes(options) {
    return options.reduce((sum, option) => sum + option.votes, 0);
  },

  onShow() {
    // console.log(this.model);
    this.set("groupedBy", this.model.groupableUserFields[0]);
    this.refreshCharts();
  },

  refreshCharts() {
    const { model } = this;

    return ajax("/polls/grouped_poll_results.json", {
      data: {
        post_id: model.post.id,
        poll_name: model.poll.name,
        user_field_name: this.groupedBy
      }
    })
      .catch(error => {
        if (error) {
          popupAjaxError(error);
        } else {
          bootbox.alert(I18n.t("poll.error_while_fetching_voters"));
        }
      })
      .then(result => {
        if (this.isDestroying || this.isDestroyed) {
          return;
        }

        this.set("charts", result.grouped_results);
      });
  },

  @action
  setGrouping(value) {
    this.set("groupedBy", value);
    this.refreshCharts();
  },

  @action
  onSelectPanel(panel) {
    this.set("displayMode", panel.id);
  }
});

function transformUserFieldToLabel(fieldName) {
  let transformed = fieldName.split("_").filter(Boolean);
  if (transformed.length > 1) {
    transformed[0] = classify(transformed[0]);
  }
  return transformed.join(" ");
}
