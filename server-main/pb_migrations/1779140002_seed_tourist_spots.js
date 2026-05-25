/// <reference path="../pb_data/types.d.ts" />

const touristSpotSeeds = [
  {
    code: "GYEONGBOKGUNG",
    name: "경복궁",
    description: "조선 왕조의 정궁",
    category: "palace",
    icon: "castle",
    color: "#8E5CF7",
    lat: 37.579617,
    lon: 126.977041,
    radius_m: 200,
    sort_order: 10,
  },
  {
    code: "N_SEOUL_TOWER",
    name: "N서울타워",
    description: "남산 정상에 위치한 서울의 상징",
    category: "landmark",
    icon: "tower",
    color: "#1FAA8C",
    lat: 37.551169,
    lon: 126.988227,
    radius_m: 200,
    sort_order: 20,
  },
  {
    code: "GWANGHWAMUN",
    name: "광화문",
    description: "경복궁의 정문",
    category: "gate",
    icon: "gate",
    color: "#F2884B",
    lat: 37.575963,
    lon: 126.976807,
    radius_m: 150,
    sort_order: 30,
  },
  {
    code: "CHANGDEOKGUNG",
    name: "창덕궁",
    description: "유네스코 세계유산 궁궐",
    category: "palace",
    icon: "castle",
    color: "#8E5CF7",
    lat: 37.582604,
    lon: 126.991958,
    radius_m: 200,
    sort_order: 40,
  },
  {
    code: "BUKCHON",
    name: "북촌한옥마을",
    description: "전통 한옥이 보존된 마을",
    category: "village",
    icon: "village",
    color: "#F2884B",
    lat: 37.582468,
    lon: 126.985556,
    radius_m: 250,
    sort_order: 50,
  },
  {
    code: "INSADONG",
    name: "인사동",
    description: "전통 문화와 예술의 거리",
    category: "street",
    icon: "street",
    color: "#F2884B",
    lat: 37.571607,
    lon: 126.985739,
    radius_m: 200,
    sort_order: 60,
  },
  {
    code: "DDP",
    name: "동대문디자인플라자",
    description: "DDP, 현대 건축의 상징",
    category: "landmark",
    icon: "modern",
    color: "#1FAA8C",
    lat: 37.566295,
    lon: 127.009264,
    radius_m: 200,
    sort_order: 70,
  },
  {
    code: "LOTTE_TOWER",
    name: "롯데월드타워",
    description: "잠실의 초고층 랜드마크",
    category: "landmark",
    icon: "tower",
    color: "#1FAA8C",
    lat: 37.512562,
    lon: 127.102489,
    radius_m: 250,
    sort_order: 80,
  },
  {
    code: "HONGDAE",
    name: "홍대거리",
    description: "젊음과 예술이 어우러진 거리",
    category: "street",
    icon: "street",
    color: "#F2884B",
    lat: 37.556489,
    lon: 126.923734,
    radius_m: 300,
    sort_order: 90,
  },
  {
    code: "HAN_RIVER",
    name: "여의도한강공원",
    description: "한강의 대표 공원",
    category: "park",
    icon: "park",
    color: "#1FAA8C",
    lat: 37.528120,
    lon: 126.933502,
    radius_m: 400,
    sort_order: 100,
  },
];

migrate((app) => {
  const touristSpotsCollection = app.findCollectionByNameOrId("tourist_spots");

  for (const seed of touristSpotSeeds) {
    let existing = null;
    try {
      existing = app.findFirstRecordByData("tourist_spots", "code", seed.code);
    } catch (_) {
      existing = null;
    }

    if (existing) {
      continue;
    }

    const record = new Record(touristSpotsCollection, {
      code: seed.code,
      name: seed.name,
      description: seed.description,
      category: seed.category,
      icon: seed.icon,
      color: seed.color,
      location: { lat: seed.lat, lon: seed.lon },
      radius_m: seed.radius_m,
      is_active: true,
      sort_order: seed.sort_order,
    });

    app.save(record);
  }
}, (app) => {
  for (const seed of touristSpotSeeds) {
    try {
      const record = app.findFirstRecordByData("tourist_spots", "code", seed.code);
      app.delete(record);
    } catch (_) {
      // ignore if record is already deleted
    }
  }
});
