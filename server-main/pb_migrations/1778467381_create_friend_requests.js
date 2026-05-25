/// <reference path="../pb_data/types.d.ts" />

migrate((app) => {
  const usersCollection = app.findCollectionByNameOrId("users");

  const friendRequestsCollection = new Collection({
    name: "friend_requests",
    type: "base",
    listRule: "requester_id = @request.auth.id || receiver_id = @request.auth.id",
    viewRule: "requester_id = @request.auth.id || receiver_id = @request.auth.id",
    createRule:
      "requester_id = @request.auth.id && receiver_id != @request.auth.id && status = \"pending\"",
    updateRule: "requester_id = @request.auth.id || receiver_id = @request.auth.id",
    deleteRule: "requester_id = @request.auth.id || receiver_id = @request.auth.id",
    fields: [
      {
        name: "requester_id",
        type: "relation",
        required: true,
        collectionId: usersCollection.id,
        minSelect: 1,
        maxSelect: 1,
        cascadeDelete: true,
      },
      {
        name: "receiver_id",
        type: "relation",
        required: true,
        collectionId: usersCollection.id,
        minSelect: 1,
        maxSelect: 1,
        cascadeDelete: true,
      },
      {
        name: "status",
        type: "text",
        required: true,
        max: 20,
      },
    ],
    indexes: [
      "CREATE UNIQUE INDEX idx_friend_requests_pending_pair ON friend_requests (CASE WHEN requester_id < receiver_id THEN requester_id ELSE receiver_id END, CASE WHEN requester_id < receiver_id THEN receiver_id ELSE requester_id END) WHERE status = 'pending'",
      "CREATE INDEX idx_friend_requests_receiver_status ON friend_requests (receiver_id, status)",
      "CREATE INDEX idx_friend_requests_requester_status ON friend_requests (requester_id, status)",
    ],
  });

  return app.save(friendRequestsCollection);
}, (app) => {
  const friendRequestsCollection = app.findCollectionByNameOrId("friend_requests");
  return app.delete(friendRequestsCollection);
});
