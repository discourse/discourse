import Component from "@glimmer/component";
import { htmlSafe } from "@ember/template";
import FlashMessage from "discourse/components/flash-message";
import { extractErrorInfo } from "discourse/lib/ajax-error";

/**
 * Displays a validation error inline within a block outlet.
 * Uses FlashMessage to render the error in a consistent format.
 */
export default class BlockOutletInlineError extends Component {
  get errorMessage() {
    const errorInfo = extractErrorInfo(this.args.error, undefined, {
      skipConsoleError: true,
    });
    return errorInfo.html ? htmlSafe(errorInfo.message) : errorInfo.message;
  }

  <template>
    <FlashMessage role="alert" @flash={{this.errorMessage}} @type="error" />
  </template>
}
