import EmberObject from "@ember/object";
import { ajax } from "discourse/lib/ajax";

export default class Product extends EmberObject {
  static findAll() {
    return ajax("/s", { method: "get" }).then((result) =>
      result.map((product) => Product.create(product))
    );
  }
}
