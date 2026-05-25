/// <reference path="../pb_data/types.d.ts" />

migrate((app) => {
  try {
    app.findCollectionByNameOrId("user_spot_visits");
    return;
  } catch (_) {}

  const usersCollection = app.findCollectionByNameOrId("users");
  const touristSpotsCollection = app.findCollectionByNameOrId("tourist_spots");

  const userSpotVisitsCollection = new Collection({
    name: "user_spot_visits",
    type: "base",
    listRule: "user = @request.auth.id",
    viewRule: "user = @request.auth.id",
    createRule: null,
    updateRule: null,
    deleteRule: null,
    fields: [
      {
        name: "user",
        type: "relation",
        required: true,
        collectionId: usersCollection.id,
        minSelect: 1,
        maxSelect: 1,
        cascadeDelete: true,
      },
      {
        name: "spot",
        type: "relation",
        required: true,
        collectionId: touristSpotsCollection.id,
        minSelect: 1,
        maxSelect: 1,
        cascadeDelete: true,
      },
      {
        name: "source",
        type: "text",
        required: false,
      },
      {
        name: "capsule",
        type: "relation",
        required: false,
        collectionId: app.findCollectionByNameOrId("capsules").id,
        minSelect: 1,
        maxSelect: 1,
        cascadeDelete: false,
      },
      {
        name: "visited_at",
        type: "date",
        required: false,
      },
    ],
    indexes: [
      "CREATE UNIQUE INDEX idx_user_spot_visits_unique ON user_spot_visits (user, spot)",
      "CREATE INDEX idx_user_spot_visits_user ON user_spot_visits (user)",
      "CREATE INDEX idx_user_spot_visits_spot ON user_spot_visits (spot)",
    ],
  });

  return app.save(userSpotVisitsCollection);
}, (app) => {
  try {
    const userSpotVisitsCollection = app.findCollectionByNameOrId("user_spot_visits");
    return app.delete(userSpotVisitsCollection);
  } catch (_) {
    return;
  }
});
