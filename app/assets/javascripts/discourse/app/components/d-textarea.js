import { TextArea } from "@ember/legacy-built-in-components";
import { attributeBindings } from "@ember-decorators/component";

@attributeBindings("aria-label")
export default class DTextarea extends TextArea {}
