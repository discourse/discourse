import { ajax } from "discourse/lib/ajax";

export default {
  finalize() {
    return ajax("/s/finalize", { method: "post" });
  },
};
