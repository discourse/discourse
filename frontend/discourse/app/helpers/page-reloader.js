import { isTesting } from "discourse/lib/environment";

export function reload() {
  if (!isTesting()) {
    location.reload();
  }
}
