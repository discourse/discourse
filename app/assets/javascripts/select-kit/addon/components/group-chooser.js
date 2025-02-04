import { classNames } from "@ember-decorators/component";
import MultiSelectComponent from "select-kit/components/multi-select";
import {
  pluginApiIdentifiers,
  selectKitOptions,
} from "select-kit/components/select-kit";

@classNames("group-chooser")
@selectKitOptions({
  allowAny: false,
})
@pluginApiIdentifiers("group-chooser")
export default class GroupChooser extends MultiSelectComponent {}
