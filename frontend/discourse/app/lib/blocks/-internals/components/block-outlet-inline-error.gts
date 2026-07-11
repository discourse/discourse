import Component from "@glimmer/component";
import { type TrustedHTML, trustHTML } from "@ember/template";
import { extractErrorInfo } from "discourse/lib/ajax-error";
import DFlashMessage from "discourse/ui-kit/d-flash-message";

interface BlockOutletInlineErrorSignature {
  Args: {
    // The error to display. `extractErrorInfo` also accepts a string, an HTTP
    // response object, or a jqXHR object, but every current consumer only
    // ever passes the `Error` surfaced by `DAsyncContent`'s `error` block.
    error: Error;
  };
}

/**
 * Displays an error inline within a block outlet.
 * Uses FlashMessage to render the error in a consistent format.
 */
export default class BlockOutletInlineError extends Component<BlockOutletInlineErrorSignature> {
  get errorMessage(): string | TrustedHTML {
    // `extractErrorInfo` is authored in untyped `.js`; annotate the fields we
    // read so the getter's return type stays precise rather than widening to `any`.
    const errorInfo: { html: boolean; message: string } = extractErrorInfo(
      this.args.error,
      undefined,
      { skipConsoleError: true }
    );
    return errorInfo.html ? trustHTML(errorInfo.message) : errorInfo.message;
  }

  <template>
    <DFlashMessage role="alert" @flash={{this.errorMessage}} @type="error" />
  </template>
}
