import Helper from "@ember/component/helper";
import { service } from "@ember/service";
import { camelize } from "@ember/string";

export default class ChatGuardianHelper extends Helper {
  @service chatGuardian;

  compute(inputs) {
    const [key, ...params] = inputs;

    if (!key) {
      return;
    }

    return this.chatGuardian[camelize(key)]?.(...params);
  }
}
