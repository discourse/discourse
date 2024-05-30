import Component from "@glimmer/component";
import { service } from "@ember/service";

export default class Test extends Component {
  @service chatStateManager;

  <template>
    <@outletArgs.form.Row as |row|>
      <row.Field
        @name="what"
        @type="text"
        @validation="length:5,16"
        @label="What is your name?"
        @help="age will help us to know you better"
        placeholder="Enter email"
      />
    </@outletArgs.form.Row>
  </template>
}
