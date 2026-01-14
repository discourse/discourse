import { ajax } from "discourse/lib/ajax";

export default {
  finalize(transaction, plan) {
    const data = {
      transaction,
      plan,
    };

    return ajax("/s/finalize", { method: "post", data });
  },
};
