/// <reference path="../pb_data/types.d.ts" />

migrate((app) => {
  const usersCollection = app.findCollectionByNameOrId("users");

  const challengesCollection = new Collection({
    name: "challenges",
    type: "base",
    listRule: "@request.auth.id != ''",
    viewRule: "@request.auth.id != ''",
    createRule: null,
    updateRule: null,
    deleteRule: null,
    fields: [
      {
        name: "code",
        type: "text",
        required: true,
        max: 100,
      },
      {
        name: "title",
        type: "text",
        required: true,
        max: 120,
      },
      {
        name: "description",
        type: "text",
        required: true,
        max: 1000,
      },
      {
        name: "category",
        type: "text",
        required: true,
        max: 50,
      },
      {
        name: "challenge_type",
        type: "text",
        required: true,
        max: 50,
      },
      {
        name: "condition_type",
        type: "text",
        required: true,
        max: 50,
      },
      {
        name: "condition_value",
        type: "number",
        required: true,
        onlyInt: true,
      },
      {
        name: "reward_type",
        type: "text",
        required: true,
        max: 50,
      },
      {
        name: "reward_value",
        type: "number",
        required: true,
        onlyInt: true,
      },
      {
        name: "icon",
        type: "text",
        required: false,
        max: 255,
      },
      {
        name: "is_active",
        type: "bool",
        required: true,
      },
      {
        name: "sort_order",
        type: "number",
        required: true,
        onlyInt: true,
      },
      {
        name: "start_at",
        type: "date",
        required: false,
      },
      {
        name: "end_at",
        type: "date",
        required: false,
      },
    ],
    indexes: [
      "CREATE UNIQUE INDEX idx_challenges_code ON challenges (code)",
      "CREATE INDEX idx_challenges_sort_order ON challenges (sort_order)",
    ],
  });

  app.save(challengesCollection);

  const userChallengesCollection = new Collection({
    name: "user_challenges",
    type: "base",
    listRule: "user = @request.auth.id",
    viewRule: "user = @request.auth.id",
    createRule: "user = @request.auth.id",
    updateRule: "user = @request.auth.id",
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
        name: "challenge",
        type: "relation",
        required: true,
        collectionId: challengesCollection.id,
        minSelect: 1,
        maxSelect: 1,
        cascadeDelete: true,
      },
      {
        name: "status",
        type: "text",
        required: true,
        max: 50,
      },
      {
        name: "progress_value",
        type: "number",
        required: true,
        onlyInt: true,
      },
      {
        name: "completed_at",
        type: "date",
        required: false,
      },
      {
        name: "claimed_at",
        type: "date",
        required: false,
      },
    ],
    indexes: [
      "CREATE UNIQUE INDEX idx_user_challenges_user_challenge ON user_challenges (user, challenge)",
      "CREATE INDEX idx_user_challenges_user_status ON user_challenges (user, status)",
    ],
  });

  return app.save(userChallengesCollection);
}, (app) => {
  const userChallengesCollection = app.findCollectionByNameOrId("user_challenges");
  app.delete(userChallengesCollection);

  const challengesCollection = app.findCollectionByNameOrId("challenges");
  return app.delete(challengesCollection);
});
