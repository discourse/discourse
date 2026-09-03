/*
Fabricators are used to create fake data for testing purposes.
The following fabricators are available in lib folder to allow
styleguide to use them, and eventually to generate dummy data
in a placeholder component. It should not be used for any other case.
*/
import ApplicationInstance from "@ember/application/instance";
import { setOwner } from "@ember/owner";
import CoreFabricators, { incrementSequence } from "discourse/lib/fabricators";
import Board from "../models/board";
import Card from "../models/card";
import Column from "../models/column";

export default class BoardsFabricators {
  constructor(owner) {
    if (owner && !(owner instanceof ApplicationInstance)) {
      throw new Error(
        "First argument of BoardsFabricators constructor must be the owning ApplicationInstance"
      );
    }
    setOwner(this, owner);
    this.coreFabricators = new CoreFabricators(owner);
  }

  card(args = {}) {
    return Card.create({
      id: args.id || incrementSequence(),
      title: args.title || "Test Card",
      unicode_title: args.unicode_title,
      card_type: args.card_type || (args.topic ? "topic" : "floater"),
      notes: args.notes || "This is a test card",
      created_at: args.created_at || moment(),
      created_by: args.created_by || this.coreFabricators.user(),
      board_id: args.board_id,
      column_id: args.column_id,
      // TODO: Add assign fabricator with avatar_template, type, and username
      assigned_to: args.assigned_to,
      inline_onebox_data: args.inline_onebox_data,
      tags: args.tags || [],
      tag_ids: args.tag_ids || [],
      topic_id: args.topic?.id || null,
      topic: args.topic || null,
    });
  }

  board(args = {}) {
    return Board.create({
      id: args.id || incrementSequence(),
      name: args.name || "Test Board",
      unicode_name: args.unicode_name,
      slug: args.slug || "test-board",
      columns: args.columns || [],
      can_write: args.can_write ?? true,
      can_manage: args.can_manage ?? true,
    });
  }

  column(args = {}) {
    return Column.create({
      id: args.id || incrementSequence(),
      title: args.title || "Test Column",
      unicode_title: args.unicode_title,
      position: args.position || 0,
    });
  }
}
