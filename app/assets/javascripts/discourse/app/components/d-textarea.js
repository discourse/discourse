import TextArea from "discourse/components/textarea";
import { attributeBindings } from "@ember-decorators/component";

@attributeBindings("aria-label")
export default class DTextarea extends TextArea {}
