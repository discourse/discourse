import EmailGroupUserChooser from "select-kit/components/email-group-user-chooser";

export default class AssigneeChooser extends EmailGroupUserChooser {
  modifyComponentForRow() {
    return "assignee-chooser-row";
  }
}
