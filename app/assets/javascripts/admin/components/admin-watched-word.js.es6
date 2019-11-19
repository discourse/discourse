import Component from "@ember/component";
import { iconHTML } from "discourse-common/lib/icon-library";
import { bufferedRender } from "discourse-common/lib/buffered-render";
import { escapeExpression } from "discourse/lib/utilities";

export default Component.extend(
  bufferedRender({
    classNames: ["watched-word"],

    buildBuffer(buffer) {
      buffer.push(iconHTML("times"));
      buffer.push(` ${escapeExpression(this.get("word.word"))}`);
    },

    click() {
      this.word
        .destroy()
        .then(() => {
          this.action(this.word);
        })
        .catch(e => {
          bootbox.alert(
            I18n.t("generic_error_with_reason", {
              error: `http: ${e.status} - ${e.body}`
            })
          );
        });
    }
  })
);
