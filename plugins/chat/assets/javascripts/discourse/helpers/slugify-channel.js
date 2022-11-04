import slugifyChannel from "discourse/plugins/chat/discourse/lib/slugify-channel";
import Helper from "@ember/component/helper";

export default class SlugifyChannel extends Helper {
  compute(inputs) {
    return slugifyChannel(inputs[0]);
  }
}
