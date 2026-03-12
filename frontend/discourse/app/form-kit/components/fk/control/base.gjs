import Component from "@glimmer/component";

export default class FKBaseControl extends Component {
  constructor(owner, args) {
    super(owner, args);

    args.field.type = this.constructor.controlType;
  }
}
