import { apiInitializer } from "discourse/lib/api";

export default apiInitializer("1.8.0", (api) => {
  api.addCommunitySectionLink?.({
    name: "westan-ranking",
    route: "westan-ranking",
    title: "Ranking Semanal",
    text: "Ranking Semanal",
    icon: "crown",
  });
});
