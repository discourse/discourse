import Controller from '@ember/controller';
import { tracked } from "@glimmer/tracking";

export default class ArtistController extends Controller {
  @tracked wikipediaData;
  @tracked reviewsData;
}
