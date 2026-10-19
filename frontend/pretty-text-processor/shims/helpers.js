import { runtime } from "../runtime-state.js";

export function helperContext() {
  return { siteSettings: { avatar_sizes: runtime.avatarSizes } };
}
