import { isTesting } from "discourse-common/config/environment";

export function reload() {
  if (!isTesting()) {
    location.reload();
  }
}
