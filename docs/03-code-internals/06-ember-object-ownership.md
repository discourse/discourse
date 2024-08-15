---
title: Ember object ownership (getOwner, service injections, etc.)
short_title: Ember object ownership
id: ember-object-ownership

---
> :warning: Importing getOwner from `discourse-common/lib/get-owner` is deprecated.

To access e.g. services there a couple of methods at your disposal.

* In components/controllers/routes you should use service injections
  ```js
  import { service } from "@ember/service";

  export default class Something extends Component {
    @service router;
  ```
* In cases where a service can be unavailable (i.e. it comes from an optional plugin) there's a `optionalService` injection
  ```js
  import optionalService from "discourse/lib/optional-service";

  export default class Something extends Component {
    @optionalService categoryBannerPresence;
  ```
* In API initializers you have the access to `api.container`
  ```js
  apiInitializer("1.0", (api) => {
    const router = api.container.lookup("service:router");
  ```
* And for a direct replacement of an existing code you can use
  ```js
  import { getOwner } from "@ember/application"
  ```
* …or if you still need the fallback shim (in a non-component/controller/route/widget context) use
  ```js
  import { getOwnerWithFallback } from "discourse-common/lib/get-owner";
  ```
