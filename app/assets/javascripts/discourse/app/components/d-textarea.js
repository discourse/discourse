import TextArea from "@ember/legacy-built-in-components/components/textarea";
import { attributeBindings } from "@ember-decorators/component";

@attributeBindings("aria-label")
export default class DTextarea extends TextArea {}
