import EmberObject from "@ember/object";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";

export interface AssociatedGroupFields {
  id: number;
  name: string;
  provider_name: string;
  label: string;
}

// eslint-disable-next-line @typescript-eslint/no-empty-object-type, @typescript-eslint/no-unsafe-declaration-merging
export default interface AssociatedGroup extends AssociatedGroupFields {}

// eslint-disable-next-line @typescript-eslint/no-unsafe-declaration-merging
export default class AssociatedGroup extends EmberObject {
  static list(): Promise<AssociatedGroup[] | undefined> {
    return (
      ajax("/associated_groups")
        .then((result: { associated_groups: AssociatedGroupFields[] }) => {
          return result.associated_groups.map((ag) =>
            AssociatedGroup.create(ag)
          );
        })
        // TODO(typescript-pending): popupAjaxError infers void; remove the cast when it declares its undefined return.
        .catch(popupAjaxError) as Promise<AssociatedGroup[] | undefined>
    );
  }
}
