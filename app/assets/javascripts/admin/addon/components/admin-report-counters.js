import { attributeBindings, classNames } from "@ember-decorators/component";
import Component from "@ember/component";
@classNames("admin-report-counters")
@attributeBindings("model.description:title")
export default class AdminReportCounters extends Component {}
