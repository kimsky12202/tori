/// <reference path="../pb_data/types.d.ts" />

migrate((app) => {
  const usersCollection = app.findCollectionByNameOrId("users");

  const userPushTokensCollection = new Collection({
    name: "user_push_tokens",
    type: "base",
    listRule: null,
    viewRule: null,
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
        name: "fcm_token",
        type: "text",
        required: true,
      },
      {
        name: "platform",
        type: "text",
        required: false,
      },
      {
        name: "device_id",
        type: "text",
        required: false,
      },
      {
        name: "is_active",
        type: "bool",
        required: false,
      },
      {
        name: "last_seen_at",
        type: "date",
        required: false,
      },
    ],
    indexes: [
      "CREATE UNIQUE INDEX idx_user_push_tokens_unique_token ON user_push_tokens (fcm_token)",
      "CREATE INDEX idx_user_push_tokens_user_active ON user_push_tokens (user, is_active)",
      "CREATE INDEX idx_user_push_tokens_device ON user_push_tokens (device_id)",
    ],
  });

  return app.save(userPushTokensCollection);
}, (app) => {
  try {
    const userPushTokensCollection = app.findCollectionByNameOrId("user_push_tokens");
    return app.delete(userPushTokensCollection);
  } catch (_) {
    return;
  }
});
