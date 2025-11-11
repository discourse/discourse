import { attributeBindings } from "@ember-decorators/component";
import TextArea from "./textarea";

@attributeBindings("aria-label")
export default class DTextarea extends TextArea {}
