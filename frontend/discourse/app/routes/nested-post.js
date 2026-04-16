import NestedRoute from "discourse/routes/nested";

export default class NestedPostRoute extends NestedRoute {
  controllerName = "nested";
  templateName = "nested";

  queryParams = {
    sort: { refreshModel: true },
    context: { refreshModel: true },
  };
}
