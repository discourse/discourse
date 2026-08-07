import { classNames } from "@ember-decorators/component";
import EmailGroupUserChooser from "discourse/select-kit/components/email-group-user-chooser";
import { selectKitOptions } from "discourse/select-kit/components/select-kit";

@classNames("email-group-user-chooser")
@selectKitOptions({
  assignmentGroups: null,
})
export default class AssignmentChooser extends EmailGroupUserChooser {
  async search(filter = "") {
    const assignmentGroups = this.assignmentGroupResults(filter);
    const resultsPromise = super.search(filter);

    if (!resultsPromise) {
      return assignmentGroups.length ? assignmentGroups : undefined;
    }

    const results = await resultsPromise;

    if (!Array.isArray(results)) {
      return results;
    }

    const resultIds = new Set(results.map((result) => result.id));
    return [
      ...results,
      ...assignmentGroups.filter((group) => !resultIds.has(group.id)),
    ];
  }

  assignmentGroupResults(filter) {
    const normalizedFilter = (filter || "").toLowerCase();

    return (this.selectKit.options.assignmentGroups || [])
      .filter(
        (groupName) =>
          !normalizedFilter ||
          groupName.toLowerCase().includes(normalizedFilter)
      )
      .map((groupName) => ({
        id: groupName,
        name: groupName,
        full_name: groupName,
        isGroup: true,
      }));
  }
}
