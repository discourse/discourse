import { prioritizeNameFallback } from "discourse/lib/settings";
import { formatUsername } from "discourse/lib/utilities";

export default function userPrioritizedName(user) {
  return prioritizeNameFallback(user.name, formatUsername(user.username));
}
