import type Query from "./models/query.js";

declare module "discourse/services/store" {
  interface ModelRegistry {
    query: Query;
  }
}
