import DiscourseRoute from "discourse/routes/discourse";

export default class AdminConfigColorPalettesShowRoute extends DiscourseRoute {
  model(params) {
    const id = parseInt(params.palette_id, 10);

    return this.modelFor("adminConfig.colorPalettes").content.find(
      (palette) => palette.id === id
    );
  }
}
