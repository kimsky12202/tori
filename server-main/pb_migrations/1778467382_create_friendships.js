/// <reference path="../pb_data/types.d.ts" />

migrate((app) => {
  const usersCollection = app.findCollectionByNameOrId("users");

  const friendshipsCollection = new Collection({
    name: "friendships",
    type: "base",
    listRule: "user_id = @request.auth.id || friend_id = @request.auth.id",
    viewRule: "user_id = @request.auth.id || friend_id = @request.auth.id",
    createRule: null,
    updateRule: null,
    deleteRule: null,
    fields: [
      {
        name: "user_id",
        type: "relation",
        required: true,
        collectionId: usersCollection.id,
        minSelect: 1,
        maxSelect: 1,
        cascadeDelete: true,
      },
      {
        name: "friend_id",
        type: "relation",
        required: true,
        collectionId: usersCollection.id,
        minSelect: 1,
        maxSelect: 1,
        cascadeDelete: true,
      },
    ],
    indexes: [
      "CREATE UNIQUE INDEX idx_friendships_unique_pair ON friendships (CASE WHEN user_id < friend_id THEN user_id ELSE friend_id END, CASE WHEN user_id < friend_id THEN friend_id ELSE user_id END)",
      "CREATE INDEX idx_friendships_user_id ON friendships (user_id)",
      "CREATE INDEX idx_friendships_friend_id ON friendships (friend_id)",
    ],
  });

  return app.save(friendshipsCollection);
}, (app) => {
  const friendshipsCollection = app.findCollectionByNameOrId("friendships");
  return app.delete(friendshipsCollection);
});
