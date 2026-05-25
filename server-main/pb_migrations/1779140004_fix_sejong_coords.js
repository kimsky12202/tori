/// <reference path="../pb_data/types.d.ts" />

// 세종 시 관광지 좌표를 좀 더 정확한 위치로 보정.
const coordPatches = [
  { code: "SEJONG_LAKE_PARK", lat: 36.499833, lon: 127.258806 },
  { code: "SEJONG_ARBORETUM", lat: 36.494722, lon: 127.249722 },
  { code: "SEJONG_BEAR_TREE_PARK", lat: 36.598300, lon: 127.281700 },
  { code: "SEJONG_PRESIDENTIAL_ARCHIVES", lat: 36.504889, lon: 127.259056 },
];

migrate((app) => {
  for (const patch of coordPatches) {
    let record;
    try {
      record = app.findFirstRecordByData("tourist_spots", "code", patch.code);
    } catch (_) {
      continue;
    }
    if (!record) continue;
    record.set("location", { lat: patch.lat, lon: patch.lon });
    app.save(record);
  }
}, (app) => {
  // 좌표 수정만 하는 마이그레이션이라 down 은 no-op.
});
