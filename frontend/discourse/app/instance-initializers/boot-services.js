import { lookup } from "discourse/lib/service";
import ClientErrorHandlerService from "discourse/services/client-error-handler";
import DeprecationWarningHandlerService from "discourse/services/deprecation-warning-handler";
export default {
  initialize(owner) {
    lookup(owner, ClientErrorHandlerService);
    lookup(owner, DeprecationWarningHandlerService);
  },
};
