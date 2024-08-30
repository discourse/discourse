import DiscourseRoute from "discourse/routes/discourse";
import RSVP from 'rsvp'; // Import RSVP
import { isEmpty } from "@ember/utils";

export default class Artists extends DiscourseRoute{
  async model(params) {
    // Fetch the main artist data
    const artistData = await this.store.find('artist', params.id);

    // URLs for additional data
    const reviewsURL = `https://critiquebrainz.org/ws/1/review/?limit=5&entity_id=${params.id}&entity_type=artist`;
    const wikipediaURL = `https://musicbrainz.org/artist/${params.id}/wikipedia-extract`;

    // Fetch reviews and Wikipezzzdia extract concurrently
    const [reviewsResponse, wikipediaResponse] = await Promise.all([
      fetch(reviewsURL),
      fetch(wikipediaURL)
    ]);

    // Process responses
    const reviewsJson = await reviewsResponse.json();
    const wikipediaJson = await wikipediaResponse.json();

    // Check for fetch errors
    if (!reviewsResponse.ok) throw new Error(reviewsJson?.message || reviewsResponse.statusText);
    if (!wikipediaResponse.ok) throw new Error(wikipediaJson?.message || wikipediaResponse.statusText);

    // Structure the model with all necessary data
    return RSVP.hash({
      artist: artistData,
      reviews: reviewsJson.reviews,
      wikipediaExtract: wikipediaJson.wikipediaExtract
    });
  }
}