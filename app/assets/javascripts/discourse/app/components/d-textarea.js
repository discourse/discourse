import { attributeBindings } from "@ember-decorators/component";
import TextArea from "discourse/components/textarea";

@attributeBindings("aria-label")
export default class DTextarea extends TextArea {}
