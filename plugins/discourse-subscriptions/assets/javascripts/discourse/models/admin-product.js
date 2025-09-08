import EmberObject from "@ember/object";
import { ajax } from "discourse/lib/ajax";

export default class AdminProduct extends EmberObject {
  static findAll() {
    return ajax("/s/admin/products", { method: "get" }).then((result) => {
      if (result === null) {
        return { unconfigured: true };
      }
      return result.map((product) => AdminProduct.create(product));
    });
  }

  static find(id) {
    return ajax(`/s/admin/products/${id}`, {
      method: "get",
    }).then((product) => AdminProduct.create(product));
  }

  isNew = false;
  metadata = {};

  destroy() {
    return ajax(`/s/admin/products/${this.id}`, { method: "delete" });
  }

  save() {
    const data = {
      name: this.name,
      statement_descriptor: this.statement_descriptor,
      metadata: this.metadata,
      active: this.active,
    };

    return ajax("/s/admin/products", {
      method: "post",
      data,
    }).then((product) => AdminProduct.create(product));
  }

  update() {
    const data = {
      name: this.name,
      statement_descriptor: this.statement_descriptor,
      metadata: this.metadata,
      active: this.active,
    };

    return ajax(`/s/admin/products/${this.id}`, {
      method: "patch",
      data,
    });
  }
}
