import { bind } from "discourse-common/utils/decorators";
import Component from "@glimmer/component";
import { action } from "@ember/object";
import { schedule } from "@ember/runloop";
import { inject as service } from "@ember/service";
import { tracked } from "@glimmer/tracking";

export default class ChatThreadOriginalMessage extends Component {}
