import DiscourseRoute from "discourse/routes/discourse";
import { ajax } from "discourse/lib/ajax";

export default class WestanRankingRoute extends DiscourseRoute {
  async model() {
    return await ajax("/westan/ranking");
  }
}
