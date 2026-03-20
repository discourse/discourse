import { classNames } from "@ember-decorators/component";
import SelectKitRowComponent from "discourse/select-kit/components/select-kit/select-kit-row";
import dDiscourseTag from "discourse/ui-kit/helpers/d-discourse-tag";

@classNames("tag-chooser-row")
export default class TagChooserRow extends SelectKitRowComponent {
  <template>
    {{dDiscourseTag this.rowName count=this.item.count noHref=true}}
  </template>
}
